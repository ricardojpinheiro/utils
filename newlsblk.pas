{
   newlsblk.pas
   
   Copyright 2025 Ricardo Jurczyk Pinheiro <ricardojpinheiro@gmail.com>
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02110-1301, USA.
   
   
}

program lsblk;

{$i d:types.pas}
{$i d:msxdos.pas}
{$i d:msxdos2.pas}
{$i d:nextor.pas}

const
    maxpartitions   = 8;
    maxdriveletters = 8;

type
    TDeviceType = (Drive, Device, Floppy, RAMDisk);
    TPartitionType = (primary, extended, logical);
    
    TPartition = record
        PartitionNumber: byte;
        PartitionType: TPartitionType;  
        DriveAssignedToPartition: char;
        PartitionSizeMajor, PartitionSizeMinor: integer;
        StartSectorMajor, StartSectorMinor: integer;
    end;

    TDevicesOnMSX = record
		ManufacturerName: TString;
		DeviceSize: real;
		Size: integer;
        DeviceNumber, DriverSlot, DriverSegment, LUN, NumberOfPartitions: byte;
        Case DeviceType: TDeviceType of
            Device: (ExtendedPartitionNumber: byte;
                Partitions: array [1..maxpartitions] of TPartition);
            Drive, Floppy, RAMDisk: (DriveAssigned: char);
    end;
var 
    Parameters:         	TTinyString;
    DeviceDriver:       	TDeviceDriver;
    DriveLetter:        	TDriveLetter;
    DevicePartition:    	TDevicePartition;
    PartitionResult:    	TPartitionResult;
    Devices:            	array [1..maxdevices] of TDevicesOnMSX;
    c:                  	char;
    i, j, k:            	byte;
    found:              	boolean;
    NumberOfDevices,
    Partitions,
    TotalDevices,
    DriveLetters: 			byte;
    Drives:					array [1..maxdriveletters] of boolean;
    HardwareDevices:		THardwareDevices;
    TempString:				TTinyString;
    RoutineDeviceDriver: 	TRoutineDeviceDriver;

procedure CommandLine (KindOf: byte);
(*
*  1 - Version
*  2 - Help
*)

begin
    case KindOf of
        1: begin (* Version *)
                writeln(' _     _     _ _       ');
                writeln('| |___| |__ | | | __   ');
                writeln('| / __| ''_ \| | |/ /  ');
                writeln('| \__ \ |_) | |   <    ');
                writeln('|_|___/_.__/|_|_|\_\   ');             
                writeln;
                Writeln('Version 0.2 - Copyright (c) 2024-25 by');
                Writeln('Brazilian MSX Crew. Some rights');
                Writeln('reserved (not many!).');
                writeln;
                Writeln('This is a utility which can show the');
                Writeln('block devices, clearly inspired by');
                Writeln('the lsblk utility, from Linux.');
                writeln;
                Writeln('It''s licensed under the GPLv3+ license.');
                writeln('Yep, free software. You are free to');
                Writeln('change and redistribute it. But don''t');
                writeln('ask me about any warranties... Use it ');
                writeln('at your own risk. ');
                Writeln('http://gnu.org/licenses/gpl.html');
                writeln;
            end;
        2: begin (* Help *)
                Writeln('Usage: lsblk <parameters>');
                Writeln('Shows info about block devices on MSX.');
                writeln;
                Writeln('Parameters: ');
                writeln('None: Shows the current block devices.');
                Writeln('/b - Print the sizes in bytes.');
                Writeln('/d <part> - Show info about a specific');
                writeln('partition.');
                Writeln('/f - Shows the used filesystems too.');
                writeln('/l - Shows block devices as a list.');
                Writeln('/h - Show this help text and exit.');
                Writeln('/v - Show version info and exit.');
                writeln;
            end;
        end;
    halt;
end;

function DOSVEREnhancedDetection: byte;
begin
    FillChar (regs, SizeOf ( regs ), 0 );
    regs.C := ctGetMSXDOSVersionNumber;
    regs.B  := $005A;
    regs.HL := $1234;
    regs.DE := $ABCD;
    regs.IX := $0000;

    MSXBDOS ( regs );
    
    if regs.B < 2 then
        DOSVEREnhancedDetection := 0
    else
        if regs.IX = 0 then
            DOSVEREnhancedDetection := 1
        else
            DOSVEREnhancedDetection := 2;
end;

procedure GetInfoAboutEverything;
var
    Dev, Part, ExtendedPartition, Slot, Subslot: byte;
    ErrorCodeInvalidDeviceDriver, ErrorCodeInvalidPartition: byte;
    Aux1, Aux2, Aux3, Aux4: real;

	procedure GetInfoAboutDevices(Dev: byte; var ErrorCodeInvalidDeviceDriver: byte);
	begin
		with DeviceDriver do
		begin
			DriverIndex 	:= Dev;
			DriverSlot 		:= HardwareDevices[Dev];
			DriverSegment 	:= $FF;
		end;

(*	Get all info about devices. *)		
		
		GetInfoDeviceDriver (DeviceDriver);
	
		with Devices[Dev] do
		begin
			DeviceNumber 		:= Dev;
			DriverSlot      	:= DeviceDriver.DriverSlot;
            DriverSegment   	:= DeviceDriver.DriverSegment;
            NumberOfPartitions 	:= 0;
            
			if DeviceDriver.DeviceOrDrive = 0 then
				DeviceType 			:= Drive    	(* Drive-based driver.  *)
			else
				DeviceType 			:= Device;   	(* Device-based driver. *)
		end;

{---------------------------------------------------------------------------}

(* Forçando a barra para setar o 2o device como... Device. Provavelmente será
   necessário trocar a forma de detecção, usando DEV_INFO e LUN_INFO. *)

if Dev = 2 then
	Devices[Dev].DeviceType := Device;
{---------------------------------------------------------------------------}

		ErrorCodeInvalidDeviceDriver := DeviceDriver.ErrorCode;

(*	Now we'll get the manufacturer's name. *)

		FillChar (RoutineDeviceDriver, SizeOf(RoutineDeviceDriver), chr(32));
		
		with RoutineDeviceDriver do
		begin
			RoutineAddress 	:= ctDEV_INFO;
			DriverSlot 		:= DeviceDriver.DriverSlot;
			DriverSegment 	:= DeviceDriver.DriverSegment;
			
			Data[0] := 0;	(*F*)
			Data[1] := Dev;	(*A*)
			Data[2] := 0;	(*C*)
			Data[3] := 1;	(*B*)
			Data[4] := 0;	(*E*)
			Data[5] := 0;	(*D*)
			Data[6] := lo(Addr(Information));	(*L*)
			Data[7] := hi(Addr(Information));	(*H*)
		end;
		
		CallRoutineInDeviceDriver (RoutineDeviceDriver);
		
		for i := 1 to SizeOf(RoutineDeviceDriver.Information) do
			Devices[Dev].ManufacturerName[i] := chr(RoutineDeviceDriver.Information[i]);
			
			Str(Dev, TempString);
		
		if Pos (chr(32), Devices[Dev].ManufacturerName) = 1 then
			Devices[Dev].ManufacturerName := 'DEVICE' + TempString
		else
		begin
			i := Pos (chr(32), Devices[Dev].ManufacturerName);
			delete (Devices[Dev].ManufacturerName, 1, i);
			
			i := Pos (chr(32), Devices[Dev].ManufacturerName);
			delete (Devices[Dev].ManufacturerName, i, length (Devices[Dev].ManufacturerName));
		end;
				
{-----------------------------}	

			with Devices[Dev] do
			begin
				writeln (' Device: ', Dev, ' Manufacturer Name: ', ManufacturerName, ' Error code: ', DeviceDriver.ErrorCode);
				writeln (' Driver Slot: ', DeviceDriver.DriverSlot, ' Driver Segment: ', DeviceDriver.DriverSegment);
				if DeviceDriver.DeviceOrDrive = 0 then
					writeln (' Device Type: Drive.')
				else
					writeln (' Device Type: Device.');
			end;
{-----------------------------}
	end;
	
	procedure GetInfoAboutPrimaryAndExtendedPartitionsOnDevice (Device, 
		Partition: byte; var ErrorCodeInvalidPartition, ExtendedPartition: byte);

(*		OK		*)

		procedure SetDevicesWithInfo;
		begin
			Devices[Device].Partitions[Partition].PartitionNumber 	:= Partition;
			Devices[Device].NumberOfPartitions := Devices[Device].NumberOfPartitions + 1;

			Devices[Device].Partitions[Partition].PartitionSizeMajor := PartitionResult.PartitionSizeMajor;
			Devices[Device].Partitions[Partition].PartitionSizeMinor := PartitionResult.PartitionSizeMinor;

			Devices[Device].Partitions[Partition].StartSectorMajor := PartitionResult.StartSectorMajor;
			Devices[Device].Partitions[Partition].StartSectorMinor := PartitionResult.StartSectorMinor;
		end;
								
	begin
		
(*  Some information which is common for each device.                       *)
        
        FillChar (DevicePartition, SizeOf (DevicePartition), 0);
        FillChar (PartitionResult, SizeOf (PartitionResult), 0);
        
        Devices[Device].LUN				:= 1;
 		DevicePartition.DriverSlot      := Devices[Device].DriverSlot;	
		DevicePartition.DriverSegment   := $FF;	{Devices[Device].DriverSegment;}
		DevicePartition.DeviceIndex     := Device;
		DevicePartition.LUN             := 1; 	{Devices[Device].LUN;}
		DevicePartition.GetInfo         := true;

(*  If the device has a device driver, then it would have partitions. *)
            
		ErrorCodeInvalidPartition 		:= 0;

(*	First we'll map all primary and extended partitions. *)

		DevicePartition.PrimaryPartition 	:= Partition;
		DevicePartition.ExtendedPartition	:= 0;
		
		GetInfoDevicePartition (DevicePartition, PartitionResult);

		ErrorCodeInvalidPartition := PartitionResult.ErrorCode;

		if (PartitionResult.PartitionType <> 0) AND (ErrorCodeInvalidPartition <> ctIPART) then
		begin
			
			if PartitionResult.PartitionType in [1, 4, 6, 14] then	(*	Primary partition. *)
			begin
				Devices[Device].Partitions[Partition].PartitionType 	:= primary;
				Devices[Device].Partitions[Partition].PartitionNumber 	:= Partition;
				SetDevicesWithInfo;
			end;
			
			if PartitionResult.PartitionType in [5, 15] then		(* Extended partition. *)
			begin									
				Devices[Device].Partitions[Partition].PartitionType 	:= extended;
				ExtendedPartition 										:= Partition;
				Devices[Device].Partitions[Partition].PartitionNumber 	:= Partition;
				SetDevicesWithInfo;
			end;
		
{-----------------------------------------------------------------------------}
{
writeln('Device ', Device, ' partition ', Partition, '  ', 
		'Slot ', Devices[Device].DriverSlot, ' Segment: ', Devices[Device].DriverSegment, 
		' LUN ', Devices[Device].LUN);

case Devices[Device].Partitions[Partition].PartitionType of
	primary:    write(' It''s a primary partition. ');
	extended:   write(' It''s a extended partition.');
	logical:   	write(' It''s a logical partition.');
end;

Aux1 := Devices[Device].Partitions[Partition].PartitionSizeMajor;
Aux2 := Devices[Device].Partitions[Partition].PartitionSizeMinor;

FixBytes(Aux1, Aux2);

writeln (' Partition size: ', SizeBytes (Aux1, Aux2)/1048576:0:0);

Aux1 := Devices[Device].Partitions[Partition].StartSectorMajor;
Aux2 := Devices[Device].Partitions[Partition].StartSectorMinor;

writeln(' Devices[', Device, '].Partitions[', Partition, '].StartSectorMajor: 	', Aux1:0:0);
writeln(' Devices[', Device, '].Partitions[', Partition, '].StartSectorMinor: 	', Aux2:0:0);

FixBytes(Aux1, Aux2);

writeln (' First sector: ', SizeBytes (Aux1, Aux2):0:0);

writeln;
}
{-----------------------------------------------------------------------------} 	
		end;
	end;
	
	procedure GetInfoAboutLogicalPartitionsOnDevice(Device, Partition: byte; 
						var ErrorCodeInvalidPartition, ExtendedPartition: byte);
	var
		LogicalPartition: byte;
	begin
		
(*  Some information which is common for each device.                       *)
        
        LogicalPartition := ExtendedPartition + Partition;
        
        Devices[Device].LUN				:= 1;
		DevicePartition.DriverSegment   := $FF; {Devices[Device].DriverSegment;}
		DevicePartition.DeviceIndex     := Device;
		DevicePartition.LUN             := 1; {Devices[Device].LUN;}
		DevicePartition.GetInfo         := true;

(*  If the device has a driver, then it would have partitions. *)
            
		ErrorCodeInvalidPartition 	:= 0;

(*	Here we must find all logical partitions into the extended partition. *)
			
		DevicePartition.PrimaryPartition 	:= ExtendedPartition;
		DevicePartition.ExtendedPartition	:= Partition;

		GetInfoDevicePartition (DevicePartition, PartitionResult);
		
		ErrorCodeInvalidPartition := PartitionResult.ErrorCode;

		if (PartitionResult.PartitionType <> 0) AND (ErrorCodeInvalidPartition <> ctIPART) then
		begin
			if PartitionResult.PartitionType in [1, 4, 6, 14, 255] then
				begin									(*	Logical partition. *)
					Devices[Device].Partitions[LogicalPartition].PartitionNumber 	:= LogicalPartition;
					Devices[Device].Partitions[LogicalPartition].PartitionType 		:= logical;
					Devices[Device].NumberOfPartitions := Devices[Device].NumberOfPartitions + 1;

					Devices[Device].Partitions[LogicalPartition].PartitionSizeMajor := PartitionResult.PartitionSizeMajor;
					Devices[Device].Partitions[LogicalPartition].PartitionSizeMinor := PartitionResult.PartitionSizeMinor;

					Devices[Device].Partitions[LogicalPartition].StartSectorMajor := PartitionResult.StartSectorMajor;
					Devices[Device].Partitions[LogicalPartition].StartSectorMinor := PartitionResult.StartSectorMinor;
				end;

{------------------------------------------------------------------------------}
{
writeln('Device ', Device, ' partition ', LogicalPartition, '  ');
writeln('Slot ', Devices[Device].DriverSlot, ' Segment: ', Devices[Device].DriverSegment, 
		' LUN ', Devices[Device].LUN);

case Devices[Device].Partitions[LogicalPartition].PartitionType of
	primary:    write(' It''s a primary partition. ');
	extended:   write(' It''s a extended partition.');
	logical:   	write(' It''s a logical partition.');
end;

writeln (	' Partition size Major: ', Devices[Device].Partitions[LogicalPartition].PartitionSizeMajor,
			' Partition size Minor: ', Devices[Device].Partitions[LogicalPartition].PartitionSizeMinor);

Aux1 := Devices[Device].Partitions[LogicalPartition].StartSectorMajor;
Aux2 := Devices[Device].Partitions[LogicalPartition].StartSectorMinor;

writeln(' Devices[', Device, '].Partitions[', LogicalPartition, '].StartSectorMajor: ', Aux1:0:0);
writeln(' Devices[', Device, '].Partitions[', LogicalPartition, '].StartSectorMinor: ', Aux2:0:0);

FixBytes (Aux1, Aux2);

Aux3 := SizeBytes (Aux1, Aux2);

writeln(' Devices[', Device, '].Partitions[', LogicalPartition, '].StartSector: ', Aux3:0:0);

writeln (	' Error Code: ', regs.A,  
			' PartitionResult.PartitionType: ', PartitionResult.PartitionType);

writeln;
}
{-----------------------------------------------------------------------------}
		end;
	end;

	procedure GetInfoAboutDriveLettersOnPartitions (DriveLetterNumber: byte; Device: byte; var Partition: byte);
	var
		i: byte;
	begin

(*	Here we must find all drive letters which is assigned to a device. *)
        
        DriveLetter.PhysicalDrive := chr(64 + DriveLetterNumber);
        GetInfoDriveLetter (DriveLetter);
        i := Partition;
        
(*	We must find the relationship comparing Aux3 and FirstDeviceSectorNumber. *)

(*	Then we'll try logical partitions. *)
        
		with DriveLetter do
        begin
			if Devices[Device].Partitions[i].PartitionType in [primary, logical] then
			begin
			
{------------------------------------------------------------------------------}
{
Aux1 := Devices[Device].Partitions[i].StartSectorMajor;
Aux2 := Devices[Device].Partitions[i].StartSectorMinor;
			
FixBytes(Aux1, Aux2);

Aux3 := SizeBytes (Aux1, Aux2);

writeln('DriveStatus: ', DriveStatus, ' DriverSlot ', DriverSlot, ' DriverSegment ', DriverSegment);
writeln('LUN ', LUN, ' DeviceIndex ', DeviceIndex, ' DeviceNumber ', Devices[Device].DeviceNumber);

case Devices[Device].Partitions[i].PartitionType of
	primary: 	writeln(' Devices[', Device, '].Partitions[', i, '].PartitionType: primary');
	extended: 	writeln(' Devices[', Device, '].Partitions[', i, '].PartitionType: extended');
	logical: 	writeln(' Devices[', Device, '].Partitions[', i, '].PartitionType: logical');
end;

writeln(' Devices[', Device, '].Partitions[', i, '].StartSectorMajor: 	', Aux1:0:0); 
writeln(' Devices[', Device, '].Partitions[', i, '].StartSectorMinor: 	', Aux2:0:0);
writeln(' Devices[', Device, '].Partitions[', i, '].FirstDeviceSectorNumber: 	', Aux3:0:0);

Aux1 := DriveLetter.StartSectorMajor;
Aux2 := DriveLetter.StartSectorMinor;

FixBytes(Aux1, Aux2);

writeln(' DriveLetter.StartSectorMajor:	', Aux1:0:0);
writeln(' DriveLetter.StartSectorMinor:	', Aux2:0:0);
writeln(' DriveLetter.FirstDeviceSectorNumber:	', DriveLetter.FirstDeviceSectorNumber:0:0);
writeln('------------------------------------------------------------');
}
{------------------------------------------------------------------------------}

				for i := Partition to Devices[Device].NumberOfPartitions do
				begin
					Aux1 := Devices[Device].Partitions[i].StartSectorMajor;
					Aux2 := Devices[Device].Partitions[i].StartSectorMinor;
					Aux3 := DriveLetter.StartSectorMajor;
					Aux4 := DriveLetter.StartSectorMinor;
					
					if	(abs(Aux1 - Aux3) <= 1) AND (abs(Aux2 - Aux4) <= 1) AND
						(Devices[Device].Partitions[i].PartitionType in [primary, logical]) then
					begin		(*	So there is a drive letter. *)
						Devices[Device].Partitions[i].DriveAssignedToPartition := DriveLetter.PhysicalDrive;
						Drives[DriveLetterNumber] := true;	(*	This drive letter is busy. *)
				
{------------------------------------------------------------------------------}
{
writeln ('Found drive letter ', DriveLetter.PhysicalDrive);
writeln ('It''s related to device ', Device, ' slot ', Devices[Device].DriverSlot, 
		' Segment ', Devices[Device].DriverSegment, ' LUN ', Devices[Device].LUN,
		' Partition ', Devices[Device].Partitions[i].PartitionNumber);
writeln('-----------------------------------------------');
}
{------------------------------------------------------------------------------}
					end;
				end;
			end;
		end;
	end;
	
	procedure GetInfoAboutDrive (DriveLetterNumber: byte; Device: byte);
	begin

(*	Here we must find all drive letters which is assigned to a drive. *)
		if Drives[DriveLetterNumber] = false then
		begin
			DriveLetter.PhysicalDrive := chr(64 + DriveLetterNumber);
			GetInfoDriveLetter (DriveLetter);

(*	We must find a relationship between the drive letter and the drive. *)
        
			with DriveLetter do
			begin
				if 	(Devices[Device].DriverSlot = DriverSlot) AND
					(DriveStatus = 1) then
				begin									(*	Found a related drive. *)
					Devices[Device].DriveAssigned := DriveLetter.PhysicalDrive;
					Drives[DriveLetterNumber] := true;	(*	This drive letter is busy. *)

{------------------------------------------------------------------------------}
{
write ('Found drive letter ', DriveLetter.PhysicalDrive);
write ('. It''s related to device ', Device, ' slot ', Devices[Device].DriverSlot);
writeln;
}
{------------------------------------------------------------------------------}
				end;
			end;
		end;	
	end;
		
	procedure GetInfoAboutRAMDisk (Device: byte);
	begin
		if Drives[8] = false then
		begin
			DriveLetter.PhysicalDrive := chr(72);
			GetInfoDriveLetter (DriveLetter);

			with DriveLetter do
			begin
				Devices[Device].DeviceNumber 		:= DeviceIndex;
				Devices[Device].DriverSlot 			:= DriverSlot;
				Devices[Device].DriverSegment 		:= DriverSegment;
				Devices[Device].LUN 				:= LUN;
				Devices[Device].NumberOfPartitions 	:= 0;
				Devices[Device].DeviceType 			:= RAMDisk;
			
				if 	(DriveStatus = 4) then
				begin									(*	Found a related drive. *)
					Devices[Device].DriveAssigned := 'H';
					Drives[8] := true;	(*	This drive letter is busy. *)

{------------------------------------------------------------------------------}

write ('Found drive letter ', PhysicalDrive);
write ('. It''s related to device ', Device, ' slot ', Devices[Device].DriverSlot);
writeln;

{------------------------------------------------------------------------------}
				end;
			end;
		end;
	end;
	
begin
    Part := 1;
    ExtendedPartition := 0;
    ErrorCodeInvalidDeviceDriver := 0;
    ErrorCodeInvalidPartition := 0;
    Aux1 := 0;
    Aux2 := 0;

(*	First of all, we should know how many devices are in the MSX. *)
	NumberOfDevices := HowManyNextorKernels (HardwareDevices);

{-------------------------------}

	writeln ('We have ', NumberOfDevices, ' Nextor devices.');

	for i := 1 to NumberOfDevices do
	begin
		SplitSlotNumber (HardwareDevices[i], Slot, Subslot);
		writeln ('Nextor kernels found in slot ', Slot, ' subslot ', Subslot);
	end;

{-------------------------------}
	
(*	There is a data structure which will guide all the discovery process. *)

	Dev := 0;

	while (ErrorCodeInvalidDeviceDriver <> ctIDRVR) do
	begin
		FillChar (DeviceDriver, SizeOf(DeviceDriver), 0);
		ErrorCodeInvalidDeviceDriver := 0;
		Dev := Dev + 1;
		GetInfoAboutDevices (Dev, ErrorCodeInvalidDeviceDriver);
    end;
    
    TotalDevices := Dev;
	Dev := 1;
	Part := 1;
	ErrorCodeInvalidPartition := 0;
	ErrorCodeInvalidDeviceDriver := 0;

	for Dev := 1 to TotalDevices do
	begin
		case Devices[Dev].DeviceType of
			Device:		begin
							while (ErrorCodeInvalidPartition <> ctIPART) AND (Part <= 4) do
							begin		

(* Find primary and extended partitions. *)
								GetInfoAboutPrimaryAndExtendedPartitionsOnDevice 
								(Dev, Part, ErrorCodeInvalidPartition, ExtendedPartition);
								Part := Part + 1;
							end;

(*	There is a extended partition. So, there are logical partitions too. *)							
							if (ExtendedPartition > 0) then
							begin
								ErrorCodeInvalidPartition := 0;
								Part := 1;
							
(* Find all logical partitions. *)
								while (ErrorCodeInvalidPartition <> ctIPART) do
								begin
									GetInfoAboutLogicalPartitionsOnDevice(Dev, Part, 
										ErrorCodeInvalidPartition, ExtendedPartition);
									Part := Part + 1;
								end;
							end;

(* Find all relationships between partitions and drive letters. *)

							Part := 1;
							for j := 1 to maxdriveletters do
							begin
								GetInfoAboutDriveLettersOnPartitions (j, Dev, Part);
								Part := Part + 1;
							end;
						end;

			Drive:		begin
							for j := 1 to maxdriveletters do
								GetInfoAboutDrive (j, Dev);
						end;

		end;
    end;
writeln(' RAMDisk: ', Dev);    
	GetInfoAboutRAMDisk (TotalDevices);
end;

procedure PrintInfoAboutPartitions;
var
	c: char;
begin
    writeln('There are ', TotalDevices, ' devices on your MSX.');

{-----------------------------------------------------------------------------}
for i := 1 to TotalDevices do
	case Devices[i].DeviceType of
		Drive: writeln(i, ' Drive-based driver. ');
		Device: writeln(i, ' Device-based driver. ');
		RAMDisk: writeln(i, ' RAMDisk. ');
	end;
{-----------------------------------------------------------------------------}
    
    for i := 1 to maxdriveletters do
		writeln (' Drive ', chr(64 + i), ': ', Drives[i]);
    
    for i := 1 to TotalDevices do
    begin
        write('Device ',    i, ' Slot ', Devices[i].DriverSlot, ' Segment ', 
                        Devices[i].DriverSegment, ' LUN ', Devices[i].LUN, ' ');
        
        case Devices[i].DeviceType of
            Drive:      begin
                            write(' Drive-based driver. ');
                            write(' Drive letter: ', Devices[i].DriveAssigned);
                        end;
                        
            Device:     begin
                            j := 1;
                            write(' Device-based driver. ');
                            writeln(' Partitions: ', Devices[i].NumberOfPartitions);
{
							case Devices[i].Partitions[j].PartitionType of
								primary: 	writeln(' Partition ', Devices[i].Partitions[j].PartitionNumber, ' is a primary partition.');
								extended: 	writeln(' Partition ', Devices[i].Partitions[j].PartitionNumber, ' is a extended partition.');
								logical: 	writeln(' Partition ', Devices[i].Partitions[j].PartitionNumber, ' is a logical partition.');
							end;

							if ord(Devices[i].Partitions[j].DriveAssignedToPartition) <> 0 then
								writeln(' Drive letter is: ', Devices[i].Partitions[j].DriveAssignedToPartition);

							writeln (' Partition size: ', Devices[i].Partitions[j].PartitionSize:0:0, ' sectors, or ', 
															((Devices[i].Partitions[j].PartitionSize)/2048):0:0, ' Mb.');
							writeln (' Initial sector: ', Devices[i].Partitions[j].PartitionSectors:0:0);
}
                            while ( j <= Devices[i].NumberOfPartitions ) do
                            begin
                                write('Partition ', Devices[i].Partitions[j].PartitionNumber);
                                case Devices[i].Partitions[j].PartitionType of
                                    primary : write(' Primary.');
                                    extended: write(' Extended.');
                                    logical : write(' Logical.');
                                end;
                                
                                c := Devices[i].Partitions[j].DriveAssignedToPartition;
                                
                                if c <> chr(32) then
									write(' Drive letter: ', c);
{
                                writeln(' Partition size: ', (Devices[i].Partitions[j].PartitionSize * 512):0:0, 
										' bytes, or ', (Devices[i].Partitions[j].PartitionSize/2097152):2:2, ' Gb.');
                                writeln(' First sector of partition: ', Devices[i].Partitions[j].PartitionSectors:0:0);
}
								writeln;
                                j := j + 1;
                            end;
                        end;

            Floppy:     write(' Floppy drive. ');
            RAMDisk:    begin
                            write(' RAM Disk. ');
                            writeln(' Drive letter: ', Devices[i].DriveAssigned);
                        end;
        end;
        writeln;
    end;
end;

procedure PrintInfo;
var
	temptext: TShortString;
	templittletext: TTinyString;
	tempint, Slot, Subslot: TInteger;
	tempreal: real;
	
begin

{-----------------------------------------------------------------------------}
for i := 1 to TotalDevices do
	case Devices[i].DeviceType of
		Drive: writeln(i, ' Drive-based driver. ');
		Device: writeln(i, ' Device-based driver. ');
		RAMDisk: writeln(i, ' RAMDisk. ');
	end;
{-----------------------------------------------------------------------------}

	writeln('NAME       NEXTOR  SLOT:SUB:LUN  REMOVABLE SIZE    READONLY  TYPE     LETTER');
	for i := 1 to TotalDevices do
	begin
		FillChar (temptext, SizeOf (temptext) , chr(32));
		case Devices[i].DeviceType of
			Device: 	begin

(*	Here we'll get device's size. *)

							FillChar (RoutineDeviceDriver, SizeOf (RoutineDeviceDriver) , chr(32));
							
							with RoutineDeviceDriver do
							begin
								RoutineAddress := ctLUN_INFO;
								DriverSlot := nNextorSlotNumber;
								DriverSegment := $FF;

								Data[0] := 0;	(*F*)
								Data[1] := i;	(*A*)
								Data[2] := 0;	(*C*)
								Data[3] := Devices[i].LUN; 	(*B*)
								Data[4] := 0;	(*E*)
								Data[5] := 0;	(*D*)
								Data[6] := lo(Addr(Information));	(*L*)
								Data[7] := hi(Addr(Information));	(*H*)

								CallRoutineInDeviceDriver (RoutineDeviceDriver);		

								j := Information[6];
								tempreal :=	16777216 * j;
								j := Information[5];
								tempreal := tempreal + 65536 * j;
								j := Information[4];
								tempreal := tempreal + 256 * j;
								j := Information[3];
								tempreal := tempreal + j;
								
								Devices[i].DeviceSize := round(int(tempreal / 2048));
							end;

(*	First line, with manufacturer name, slot and subslot, and more info. *)			

							Str(i, templittletext);
							j := 12 - length(Devices[i].ManufacturerName);
							temptext 	:= 	Devices[i].ManufacturerName + templittletext;
							for k := 1 to j do
								insert (chr(32), temptext, length(temptext) + 1);
								
							temptext 	:=	temptext + '1' + '       ';

							Slot 		:= ((Devices[i].DriverSlot mod 128) mod 4);
							Subslot 	:= ((Devices[i].DriverSlot mod 128) div 4);
							Str (Slot, templittletext);
							temptext 	:= temptext + templittletext + '   ';
							Str (Subslot, templittletext);

							temptext 	:= temptext + templittletext + '   ';
							Str (Devices[i].LUN, templittletext);

							temptext 	:= temptext + templittletext + '      NO     ';

							FillChar (templittletext, SizeOf (templittletext), chr(32));
							
							Str (Devices[i].DeviceSize:0:0, templittletext);
							
							j := 4 - length(templittletext);
							for k := 1 to j do
								insert (chr(32), templittletext, 1);

							temptext 	:= temptext + templittletext + ' Mb    NO     disk';
							
							writeln(temptext);

(*	Let's print info about partitions. *)							

							j := 1;
							while ( j <= Devices[i].NumberOfPartitions ) do
							begin
								Str (Devices[i].Partitions[j].PartitionNumber, templittletext);
								temptext := '|_part' + templittletext + '      1' + '       ';
								Str (Slot, templittletext);
								temptext := temptext + templittletext + '   ';
								Str (Subslot, templittletext);
								temptext := temptext + templittletext + '   ';
								Str (Devices[i].LUN, templittletext);
								temptext := temptext + templittletext + '      NO    ';
								
								c:= Devices[i].Partitions[j].DriveAssignedToPartition;
								if c <> chr(32) then
								begin
									tempreal := round(GetDriveSpaceInfo (c, ctGetTotalSpace) / 1024);
									Str (tempreal:0:0, templittletext);

									if length(templittletext) in [2, 3] then
										insert(chr(32), templittletext, 1);

									temptext := temptext + '  ' + templittletext + ' Mb    NO     ';
								end
								else
									temptext := temptext + ' xxxx Mb    NO     ';
								
								case Devices[i].Partitions[j].PartitionType of
                                    primary : 	templittletext := 'primary  ';
                                    extended: 	templittletext := 'extended ';
                                    logical : 	begin
													templittletext := 'logical  ';
													insert ('  ', temptext, 1);
													delete (temptext, 10, 2);
												end;
                                end;
                                temptext := temptext + templittletext; 
                                
                                if c <> chr(32) then
								temptext := temptext + c +':';
								writeln(temptext);
								
								j := j + 1;
							end;
							 
							
						end;
					
			Drive:		begin
							temptext := 'DRIVE' + '        0' + '       ';
							Slot := ((Devices[i].DriverSlot mod 128) mod 4);
							Subslot := ((Devices[i].DriverSlot mod 128) div 4);
							Str (Slot, templittletext);
							temptext := temptext + templittletext + '   ';
							Str (Subslot, templittletext);
							temptext := temptext + templittletext + '   ';
							templittletext := chr(32);
							temptext := temptext + templittletext  + '     YES      720 Kb    NO     ';
							temptext := temptext + 'disk     ';
                            if Devices[i].DriveAssigned <> chr(32) then
								temptext := temptext + Devices[i].DriveAssigned +':';
							writeln(temptext);
						end;
					
			RAMDisk: 	begin
							temptext := 'RAMDISK'+ '      0' + '       ';
							Slot := ((Devices[i].DriverSlot mod 128) mod 4);
							Subslot := ((Devices[i].DriverSlot mod 128) div 4);
							Str (Slot, templittletext);
							temptext := temptext + templittletext + '   ';
							Str (Subslot, templittletext);
							temptext := temptext + templittletext + '   ';
							templittletext := chr(32);
							temptext := temptext + templittletext + '      NO      ';
							if Devices[i].DriveAssigned <> chr(32) then
							begin
								Str (GetDriveSpaceInfo (chr(72), ctGetTotalSpace):0:0, templittletext);

								if length(templittletext) in [2, 3] then
									insert(chr(32), templittletext, 1);
							end	
							
							else
								templittletext := 'xxxx';
							temptext := temptext + templittletext + ' Kb    NO     ';
							temptext := temptext + 'ramdisk  ';
                            if Devices[i].DriveAssigned <> chr(32) then
								temptext := temptext + Devices[i].DriveAssigned +':';
							writeln(temptext);
						end;
		end;
	end;
end;

BEGIN
(*  Detects if it's MSX-DOS 1, MSX-DOS 2 or Nextor. *)
	
	FillChar (Drives, SizeOf(Drives), false);
	FillChar (Devices, SizeOf(Devices), chr(32));

    case DOSVEREnhancedDetection of
        0:  begin
                writeln ('MSX-DOS 1 detected, so lsblk won''t run.');
                halt;
            end;
        1:  begin
                writeln ('MSX-DOS 2 detected, so lsblk won''t run.');
                halt;
            end;
    end;

    GetInfoAboutEverything;

    if paramcount = 0 then
    (*  Shows current information about zero allocation mode. *)

        PrintInfoAboutPartitions
{
		PrintInfo
}
    else
    begin
        for i := 1 to paramcount do
        begin
            Parameters := paramstr(i);
                for j := 1 to length(Parameters) do
                    Parameters[j] := upcase(Parameters[j]);

                c := Parameters[2];
                if Parameters[1] = '/' then
                begin
                    delete(Parameters, 1, 2);
                (*  Parameters. *)
                    case c of
                        'V': CommandLine(1);        (* Help     *)
                        'H': CommandLine(2);        (* Version  *)
                        'B':    begin               (* Print the sizes in bytes. *)
                                end;
                                
                        'D':    begin               (* Show info about a specific partition. *)
                                end;
                                
                        'F':    begin               (* Shows the used filesystems too. *)
                                end;
                                
                        'L':    begin               (* Shows block devices as a list. *)
                                end;
                        
                    end;
                end;
        end;
    end;    
END.

