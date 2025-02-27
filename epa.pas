{
   lsblk.pas
   
   Copyright 2024 Ricardo Jurczyk Pinheiro <ricardojpinheiro@gmail.com>
   
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
    
    Partition = record
        PartitionNumber: byte;
        PartitionType: TPartitionType;  
        DriveAssignedToPartition: char;
        PartitionSize: real;
        PartitionSectors: real;
    end;

    DevicesOnMSX = record
        DeviceNumber, DriverSlot, DriverSegment, LUN, NumberOfPartitions: byte;
        Case DeviceType: TDeviceType of
            Device: (ExtendedPartitionNumber: byte;
                Partitions: array [1..maxpartitions] of Partition);
            Drive, Floppy, RAMDisk: (DriveAssigned: char);
    end;
var 
    Parameters:         	TTinyString;
    DeviceDriver:       	TDeviceDriver;
    DriveLetter:        	TDriveLetter;
    DevicePartition:    	TDevicePartition;
    PartitionResult:    	TPartitionResult;
    Devices:            	array [1..maxdevices] of DevicesOnMSX;
    c:                  	char;
    i, j, k:            	byte;
    found:              	boolean;
    HowManyDevices, 
    HowManyPartitions, 
    HowManyDriveLetters: 	byte;
    Drives:					array [0..maxdriveletters] of boolean;

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
                Writeln('Version 0.1 - Copyright (c) 2024-25 by');
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

procedure GatherInfoAboutEverything;
var
    Dev, Part, ExtendedPartition: byte;
    ErrorCodeInvalidDeviceDriver, ErrorCodeInvalidPartition: byte;
    aux1, aux2: real;

	procedure GatherInfoAboutDevices (HowManyDevices: byte; 
									var ErrorCodeInvalidDeviceDriver: byte);
	begin
		with DeviceDriver do
		begin
			DriverIndex 	:= HowManyDevices;
			DriverSlot 		:= 0;
			DriverSegment 	:= 0;
		end;

        GetInfoDeviceDriver (DeviceDriver);

		with Devices[HowManyDevices] do
		begin
			DeviceNumber 	:= DeviceDriver.DriverIndex;
			DriverSlot      := DeviceDriver.DriverSlot;
            DriverSegment   := DeviceDriver.DriverSegment;
            
			if DeviceDriver.DeviceOrDrive = 0 then
			begin									(* Drive-based driver.  *)
				DeviceType 			:= Drive;    
				NumberOfPartitions 	:= 0;
			end
			else
				DeviceType 			:= Device;   	(* Device-based driver. *)
		end;
		ErrorCodeInvalidDeviceDriver := regs.A;
	end;
	
	procedure GatherInfoAboutPrimaryAndExtendedPartitionsOnDevice (Device, 
		Partition: byte; var ErrorCodeInvalidPartition, ExtendedPartition: byte);
								
	begin
		
(*  Some information which is common for each device.                       *)
        
        Devices[Device].LUN				:= 1;
        
		DevicePartition.DriverSlot      := Devices[Device].DriverSlot;
		DevicePartition.DriverSegment   := Devices[Device].DriverSegment;
		DevicePartition.DeviceIndex     := Device;
		DevicePartition.LUN             := Devices[Device].LUN;
		DevicePartition.GetInfo         := true;

(*  If the device has a driver, then it would have partitions. *)
            
		ErrorCodeInvalidPartition 	:= 0;

(*	First we'll map all primary and extended partitions. *)
			
		DevicePartition.PrimaryPartition 	:= Partition;
		DevicePartition.ExtendedPartition	:= 0;
		
		GetInfoDevicePartition (DevicePartition, PartitionResult);
		
		ErrorCodeInvalidPartition := regs.A;

		if (PartitionResult.PartitionType <> 0) AND (ErrorCodeInvalidPartition <> ctIPART) then
		begin
			if PartitionResult.PartitionType in [1, 4, 6, 14] then
			begin									(*	Primary partition. *)
				Devices[Device].Partitions[Partition].PartitionNumber 	:= Partition;
				Devices[Device].Partitions[Partition].PartitionType 	:= primary;
				Devices[Device].NumberOfPartitions := Devices[Device].NumberOfPartitions + 1;

				Aux1 := PartitionResult.PartitionSizeMajor;
				Aux2 := PartitionResult.PartitionSizeMinor;
				FixBytes(Aux1, Aux2);
				Devices[Device].Partitions[Partition].PartitionSize		:= SizeBytes (Aux1, Aux2);

				Aux1 := PartitionResult.StartSectorMajor;
				Aux2 := PartitionResult.StartSectorMinor;
				FixBytes(Aux1, Aux2);
				Devices[Device].Partitions[Partition].PartitionSectors	:= SizeBytes (Aux1, Aux2);
			end;
			if PartitionResult.PartitionType = 5 then
			begin									(* Extended partition. *)										
				Devices[Device].Partitions[Partition].PartitionNumber 	:= Partition;
				Devices[Device].Partitions[Partition].PartitionType 	:= extended;
				ExtendedPartition 										:= Partition;
				Devices[Device].NumberOfPartitions := Devices[Device].NumberOfPartitions + 1;

				Aux1 := PartitionResult.PartitionSizeMajor;
				Aux2 := PartitionResult.PartitionSizeMinor;
				FixBytes(Aux1, Aux2);
				Devices[Device].Partitions[Partition].PartitionSize		:= SizeBytes (Aux1, Aux2);

				Aux1 := PartitionResult.StartSectorMajor;
				Aux2 := PartitionResult.StartSectorMinor;
				FixBytes(Aux1, Aux2);
				Devices[Device].Partitions[Partition].PartitionSectors	:= SizeBytes (Aux1, Aux2);
			end;
		
{-----------------------------------------------------------------------------}
{
writeln('Device ', Device, ' partition ', Partition, '  ');
writeln('Slot ', Devices[Device].DriverSlot, ' Segment: ', Devices[Device].DriverSegment, 
		' LUN ', Devices[Device].LUN);

case Devices[Device].Partitions[Partition].PartitionType of
	primary:    writeln('It''s a primary partition. ');
	extended:   writeln('It''s a extended partition.');
	logical:   	writeln('It''s a logical partition.');
end;

writeln ('Partition size: ', Devices[Device].Partitions[Partition].PartitionSize:2:0);
writeln ('Initial sector: ', Devices[Device].Partitions[Partition].PartitionSectors:2:0);
writeln;    
}
{-----------------------------------------------------------------------------} 	
		end;
	end;
	
	procedure GatherInfoAboutLogicalPartitionsOnDevice(Device, Partition: byte; 
						var ErrorCodeInvalidPartition, ExtendedPartition: byte);
	var
		LogicalPartition: byte;
	begin
		
(*  Some information which is common for each device.                       *)
        
        LogicalPartition := ExtendedPartition + Partition;
        
        Devices[Device].LUN				:= 1;
        
		DevicePartition.DriverSlot      := Devices[Device].DriverSlot;
		DevicePartition.DriverSegment   := Devices[Device].DriverSegment;
		DevicePartition.DeviceIndex     := Device;
		DevicePartition.LUN             := Devices[Device].LUN;
		DevicePartition.GetInfo         := true;

(*  If the device has a driver, then it would have partitions. *)
            
		ErrorCodeInvalidPartition 	:= 0;

(*	Here we must find all logical partitions into the extended partition. *)
			
		DevicePartition.PrimaryPartition 	:= ExtendedPartition;
		DevicePartition.ExtendedPartition	:= Partition;

		GetInfoDevicePartition (DevicePartition, PartitionResult);
		
		ErrorCodeInvalidPartition := regs.A;

		if (PartitionResult.PartitionType <> 0) AND (ErrorCodeInvalidPartition <> ctIPART) then
		begin
		if PartitionResult.PartitionType in [1, 4, 6, 14, 255] then
			begin									(*	Primary partition. *)
				Devices[Device].Partitions[LogicalPartition].PartitionNumber 	:= LogicalPartition;
				Devices[Device].Partitions[LogicalPartition].PartitionType 		:= logical;
				Devices[Device].NumberOfPartitions := Devices[Device].NumberOfPartitions + 1;

				Aux1 := PartitionResult.PartitionSizeMajor;
				Aux2 := PartitionResult.PartitionSizeMinor;
				FixBytes(Aux1, Aux2);
				Devices[Device].Partitions[LogicalPartition].PartitionSize		:= SizeBytes (Aux1, Aux2);

				Aux1 := PartitionResult.StartSectorMajor;
				Aux2 := PartitionResult.StartSectorMinor;
				FixBytes(Aux1, Aux2);
				Devices[Device].Partitions[LogicalPartition].PartitionSectors		:= SizeBytes (Aux1, Aux2);
			end;

{-----------------------------------------------------------------------------}
{
writeln('Device ', Device, ' partition ', LogicalPartition, '  ');
writeln('Slot ', Devices[Device].DriverSlot, ' Segment: ', Devices[Device].DriverSegment, 
		' LUN ', Devices[Device].LUN);

case Devices[Device].Partitions[LogicalPartition].PartitionType of
	primary:    writeln('It''s a primary partition. ');
	extended:   writeln('It''s a extended partition.');
	logical:   	writeln('It''s a logical partition.');
end;

writeln ('Partition size: ', Devices[Device].Partitions[LogicalPartition].PartitionSize:2:0);
writeln ('Initial sector: ', Devices[Device].Partitions[LogicalPartition].PartitionSectors:2:0);

writeln ('Error Code: ', regs.A);
writeln ('PartitionResult.PartitionType: ', PartitionResult.PartitionType);
writeln;    
}
{-----------------------------------------------------------------------------} 	
		end;
	end;
	
	procedure GatherInfoAboutDriveLettersOnPartitions (DriveLetterNumber: byte; Device: byte);
	var
		Partition, i: byte;
	begin

(*	Here we must find all drive letters which is assigned to a device. *)
        
        DriveLetter.PhysicalDrive := chr(64 + DriveLetterNumber);
        GetInfoDriveLetter (DriveLetter);

(*	We must find the relationship comparing the PartitionSectors and the 
	FirstDeviceSectorNumber. *)

(*	Then we'll try logical partitions. *)
        
        with DriveLetter do
        begin
			i := 1;
			
{------------------------------------------------------------------------------}
{
		writeln('DriveStatus: ', DriveStatus, ' DriverSlot ', DriverSlot, ' DriverSegment ', DriverSegment);
		writeln('LUN ', LUN, ' DeviceIndex ', DeviceIndex, ' DeviceNumber ', Devices[Device].DeviceNumber);
		case Devices[Device].Partitions[i].PartitionType of
			primary: 	writeln(' Devices[', Device, '].Partitions[', i, '].PartitionType: primary');
			extended: 	writeln(' Devices[', Device, '].Partitions[', i, '].PartitionType: extended');
			logical: 	writeln(' Devices[', Device, '].Partitions[', i, '].PartitionType: logical');
		end;
}
{------------------------------------------------------------------------------}

			while Devices[Device].Partitions[i].PartitionSectors <> FirstDeviceSectorNumber do
				i := i + 1;

			if i <= Devices[Device].NumberOfPartitions then
			begin
				Devices[Device].Partitions[i].DriveAssignedToPartition := DriveLetter.PhysicalDrive;
				Drives[DriveLetterNumber] := true;	(*	This drive letter is busy. *)

{------------------------------------------------------------------------------}
{
writeln ('Found drive letter ', DriveLetter.PhysicalDrive);
writeln ('It''s related to device ', Device, ' slot ', Devices[Device].DriverSlot, 
		' Segment ', Devices[Device].DriverSegment, ' LUN ', Devices[Device].LUN,
		' Partition ', Devices[Device].Partitions[i].PartitionNumber);
}
{------------------------------------------------------------------------------}
			end;
		end;
	end;

	procedure GatherInfoAboutDrive (DriveLetterNumber: byte; Device: byte);
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
	
	procedure GatherInfoAboutRAMDisk (Device: byte);
	begin
		if Drives[8] = false then
		begin
			DriveLetter.PhysicalDrive := chr(73);
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
{
write ('Found drive letter ', PhysicalDrive);
write ('. It''s related to device ', Device, ' slot ', Devices[Device].DriverSlot);
writeln;
}
{------------------------------------------------------------------------------}
				end;
			end;
		end;
	end;

begin
    FillChar(Devices, SizeOf ( Devices ), 0 );
    FillChar(Regs, SizeOf ( Regs ), 0 );

(*  Find how many devices are used in the MSX and get info about them. *)

    Dev := 0;
    ErrorCodeInvalidDeviceDriver := 0;
	
	while (Dev <= maxdevices) AND (ErrorCodeInvalidDeviceDriver <> ctIDRVR) do
	begin
		Dev := Dev + 1;
		GatherInfoAboutDevices (Dev, ErrorCodeInvalidDeviceDriver);
		
{-----------------------------------------------------------------------------}
{
case Devices[Dev].DeviceType of
    Drive: 	write (' Device ', Devices[Dev].DeviceNumber , ' has a drive-based driver. ');
    Device:	write (' Device ', Dev , ' has a device-based driver. ');
end;
write ('Driver Slot: ', Devices[Dev].DriverSlot, ' Segment: ', Devices[Dev].DriverSegment);
writeln;
}
{-----------------------------------------------------------------------------}

    end;

	HowManyDevices := Dev - 1;

    Dev 	:= 0;
    Part	:= 1;
    ErrorCodeInvalidPartition := 0;
    
    while Dev <= HowManyDevices do
    begin
		case Devices[Dev].DeviceType of
			Device:		begin
							while ErrorCodeInvalidPartition <> ctIPART do
							begin		(* Find primary and extended partitions. *)
								GatherInfoAboutPrimaryAndExtendedPartitionsOnDevice 
								(Dev, Part, ErrorCodeInvalidPartition, ExtendedPartition);
								Part := Part + 1;
							end;
							
							ErrorCodeInvalidPartition := 0;
							Part := 1;		(* Find all logical partitions. *)
							while ErrorCodeInvalidPartition <> ctIPART do
							begin
								GatherInfoAboutLogicalPartitionsOnDevice(Dev, Part, 
									ErrorCodeInvalidPartition, ExtendedPartition);
								Part := Part + 1;
							end;

(* Find all relationships between partitions and drive letters. *)
{
							for j := 1 to maxdriveletters do
								GatherInfoAboutDriveLettersOnPartitions (j, Dev);
}
						end;

			Drive:		for j := 1 to maxdriveletters do
							GatherInfoAboutDrive (j, Dev);
		end;
		Dev := Dev + 1;
	end;
	    
	GatherInfoAboutRAMDisk (Dev);

	HowManyDevices := Dev;
end;

procedure PrintInfoAboutPartitions;
begin
    writeln('There are ', HowManyDevices, ' devices on your MSX.');

{-----------------------------------------------------------------------------}
for i := 0 to HowManyDevices do
	case Devices[i].DeviceType of
		Drive: writeln(i, ' Drive-based driver. ');
		Device: writeln(i, ' Device-based driver. ');
		RAMDisk: writeln(i, ' RAMDisk. ');
	end;
{-----------------------------------------------------------------------------}

    
    for i := 1 to maxdriveletters do
		writeln (' Drive ', chr(64 + i), ': ', Drives[i]);
    
    for i := 1 to HowManyDevices do
    begin
        writeln('Device ',    i, ' Slot ', Devices[i].DriverSlot, ' Segment ', 
                        Devices[i].DriverSegment, ' LUN ', Devices[i].LUN, ' ');
        
        case Devices[i].DeviceType of
            Drive:      begin
                            write(' Drive-based driver. ');
                            writeln(' Drive letter: ', Devices[i].DriveAssigned);
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
								writeln(' Drive letter: ', Devices[i].Partitions[j].DriveAssignedToPartition);

							writeln (' Partition size: ', Devices[i].Partitions[j].PartitionSize:0:0, ' sectors, or ', 
															((Devices[i].Partitions[j].PartitionSize)/2048):0:0, ' Mb.');
							writeln (' Initial sector: ', Devices[i].Partitions[j].PartitionSectors:0:0);
}							

                            while ( j <= Devices[i].NumberOfPartitions ) do
                            begin
                                writeln;
                                writeln('Partition ', Devices[i].Partitions[j].PartitionNumber);
                                case Devices[i].Partitions[j].PartitionType of
                                    primary : writeln(' It''s a primary partition.');
                                    extended: writeln(' It''s a extended partition.');
                                    logical : writeln(' It''s a logical partition.');
                                end;
                                writeln(' Drive letter: ', Devices[i].Partitions[j].DriveAssignedToPartition);
                                writeln(' Partition size: ', (Devices[i].Partitions[j].PartitionSize * 512):0:0, 
										' bytes, or ', (Devices[i].Partitions[j].PartitionSize/2097152):2:2, ' Gb.');
                                writeln(' First sector of partition: ', Devices[i].Partitions[j].PartitionSectors:0:0);
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

BEGIN
(*  Detects if it's MSX-DOS 1, MSX-DOS 2 or Nextor. *)
	
	FillChar (Drives, SizeOf(Drives), false);

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

    GatherInfoAboutEverything;

    if paramcount = 0 then
    (*  Shows current information about zero allocation mode. *)

        PrintInfoAboutPartitions

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

