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
	maxpartitions 	= 8;
	maxdevices		= 8;
	maxdriveletters	= 8;

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
		DeviceNumber, DriverSlot, DriverSegment, LUN: byte;
		Case DeviceType: TDeviceType of
			Device: (ExtendedPartitionNumber: byte;
				Partitions: array [1..maxpartitions] of Partition);
			Drive, Floppy, RAMDisk: (DriveAssigned: char);
    end;
var 
	Parameters:			TTinyString;
	DeviceDriver: 		TDeviceDriver;
	DriveLetter: 		TDriveLetter;
	DevicePartition: 	TDevicePartition;
	PartitionResult: 	TPartitionResult;
	Devices: 			array [1..maxdevices] of DevicesOnMSX;
	c:					Char;
	i, j, k:			byte;
	found:				boolean;
	HowManyDevices:		byte;

procedure CommandLine (KindOf: byte);
(*
*  1 - Version
*  2 - Help
*)

begin
    case KindOf of
        1: begin (* Version *)
				writeln(' _     _     _ _		');
				writeln('| |___| |__ | | | __	');
				writeln('| / __| ''_ \| | |/ /	');
				writeln('| \__ \ |_) | |   <	');
				writeln('|_|___/_.__/|_|_|\_\	');				
				writeln;
                Writeln('Version 0.1 - Copyright (c) 2024 by');
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
	
	writeln;
	if regs.B < 2 then
		DOSVEREnhancedDetection := 0
	else
		if regs.IX = 0 then
			DOSVEREnhancedDetection := 1
		else
			DOSVEREnhancedDetection := 2;
end;

procedure GatherInfoAboutPartitions;
var
	ErrorCodeInvalidDeviceDriver, ErrorCodeInvalidPartitionNumber: byte;
	aux1, aux2, temp1, temp2: real;
	

begin
	FillChar(Devices, SizeOf ( Devices ), 0 );
	FillChar(Regs, SizeOf ( Regs ), 0 );

(* 	Find how many devices are used in the MSX and get information about them. *)

	HowManyDevices := 1;
	ErrorCodeInvalidDeviceDriver := 0;

	while ErrorCodeInvalidDeviceDriver <> ctIDRVR do
	begin
		DeviceDriver.DriverIndex := HowManyDevices;
		GetInfoDeviceDriver (DeviceDriver);
		ErrorCodeInvalidDeviceDriver := regs.A;
{-----------------------------------------------------------------------------}
{
writeln (' Device ', HowManyDevices, ' on your MSX.');
}
{-----------------------------------------------------------------------------}

		Devices[HowManyDevices].DeviceNumber := HowManyDevices;
		
		if DeviceDriver.DeviceOrDrive = 0 then
			Devices[HowManyDevices].DeviceType := Drive 	(* Drive-based driver.	*)
		else
			Devices[HowManyDevices].DeviceType := Device; 	(* Device-based driver. *)

		with Devices[HowManyDevices] do
		begin
			DriverSlot 		:= DeviceDriver.DriverSlot;
			DriverSegment 	:= DeviceDriver.DriverSegment;
			LUN 			:= 1;
		end;

{-----------------------------------------------------------------------------}
{
case Devices[HowManyDevices].DeviceType of
	Drive: 		writeln (' Device ', HowManyDevices , ' has a drive-based driver.	');
	Device: 	writeln (' Device ', HowManyDevices , ' has a device-based driver.	');
end;
}
{-----------------------------------------------------------------------------}
		
		HowManyDevices := HowManyDevices + 1;
	end;

	i := 1;
	while i <= HowManyDevices do
	begin

(*	Some information which is common for each device. 						*)
		
		if Devices[i].DeviceType = Device then
		begin
			DevicePartition.DriverSlot 		:= Devices[i].DriverSlot;
			DevicePartition.DriverSegment 	:= Devices[i].DriverSegment;
			DevicePartition.DeviceIndex 	:= i;
			DevicePartition.LUN 			:= Devices[i].LUN;
			DevicePartition.GetInfo 		:= true;
		end;

(*	If the device has a driver, then it would have partitions. Here goes an 
	lousy effort to map primary (1) and extended (2) partitions, and associates 
	a drive letter to the partition. Obviously, the extended partition doesn't
	have any drive letters associated.										*)
			
		j := 0;
				
		while ( j <= 4 ) and ( ErrorCodeInvalidPartitionNumber <> ctIPART ) do
		begin
			j := j + 1;
			DevicePartition.PrimaryPartition 	:= j;
			DevicePartition.ExtendedPartition 	:= 0;
			GetInfoDevicePartition (DevicePartition, PartitionResult);
			ErrorCodeInvalidPartitionNumber 	:= regs.A;
			
			Devices[i].Partitions[j].PartitionNumber := j;
			
			if ErrorCodeInvalidPartitionNumber <> ctIPART then
			case PartitionResult.PartitionType of
				1,4,6,14: 	begin
								Devices[i].Partitions[j].PartitionType 		:= primary;
								
								temp1 := PartitionResult.PartitionSizeMajor;
								temp2 := PartitionResult.PartitionSizeMinor;
								FixBytes (temp1, temp2);
								
								Devices[i].Partitions[j].PartitionSize 		:= 65536 * temp1 + temp2;

								temp1 := PartitionResult.StartSectorMajor;
								temp2 := PartitionResult.StartSectorMinor;
								FixBytes (temp1, temp2);
								
								Devices[i].Partitions[j].PartitionSectors 	:= 65536 * temp1 + temp2;
								
								aux1 := Devices[i].Partitions[j].PartitionSectors;
								
								aux2 := 0;
								k := 1;
								
								while ( k <= maxdriveletters ) and ( aux1 <> aux2 ) do
								begin
									DriveLetter.PhysicalDrive := chr(64 + k);
									GetInfoDriveLetter (DriveLetter);
									aux2 := DriveLetter.FirstDeviceSectorNumber;
									if Devices[i].Partitions[j].PartitionSectors = DriveLetter.FirstDeviceSectorNumber then
										Devices[i].Partitions[j].DriveAssignedToPartition := DriveLetter.PhysicalDrive;
									k := k + 1;
								end;
							end;
				5: begin
						Devices[i].Partitions[j].PartitionType 		:= extended;
						Devices[i].ExtendedPartitionNumber 			:= DevicePartition.PrimaryPartition;
						Devices[i].Partitions[j].PartitionNumber 	:= DevicePartition.PrimaryPartition;
						ErrorCodeInvalidPartitionNumber 			:= ctIPART;
					end;
			end;

{-----------------------------------------------------------------------------}

write('Device ', i, ' partition ', j, '  ');
case Devices[i].Partitions[j].PartitionType of
	primary: 	writeln('It''s a primary partition.	');
	extended: 	writeln('It''s a extended partition.');
end;
writeln ('Drive letter: ', Devices[i].Partitions[j].DriveAssignedToPartition);
writeln ('Partition size: ', Devices[i].Partitions[j].PartitionSize:2:0);
writeln ('Initial sector: ', Devices[i].Partitions[j].PartitionSectors:2:0);
writeln;	

{-----------------------------------------------------------------------------}			

		end;
		i := i + 1;
	end;

(*	Now we must find all logical (3) partitions in the extended partition, and 
	associate them with the remaining drive letters. 	*)

	i := 1;
	while ( i <= maxpartitions ) and ( Devices[i].DeviceType = Device ) do
	begin

(*	Some information which is common for each device. 						*)

		DevicePartition.DriverSlot 			:= Devices[i].DriverSlot;
		DevicePartition.DriverSegment 		:= Devices[i].DriverSegment;
		DevicePartition.DeviceIndex 		:= i;
		DevicePartition.LUN 				:= Devices[i].LUN;
		DevicePartition.GetInfo 			:= true;
		DevicePartition.PrimaryPartition 	:= Devices[i].ExtendedPartitionNumber;

(*	Here goes my lousy effort to map all logical (3) partitions, and associates
	each drive letter to the right logical partition. Well... I hope so!	*)
			
		j := 0;
		ErrorCodeInvalidPartitionNumber := 0;
		
		while ( j <= maxpartitions ) and ( ErrorCodeInvalidPartitionNumber <> ctIPART ) do
		begin
			j := j + 1;
			DevicePartition.ExtendedPartition 	:= j;
			GetInfoDevicePartition (DevicePartition, PartitionResult);
			ErrorCodeInvalidPartitionNumber 	:= regs.A;
			
			if ErrorCodeInvalidPartitionNumber <> ctIPART then
				if PartitionResult.PartitionType in [1, 4, 6, 14] then
				begin
					Devices[i].Partitions[j].PartitionType		:= logical;
					
					temp1 := PartitionResult.PartitionSizeMajor;
					temp2 := PartitionResult.PartitionSizeMinor;
					FixBytes (temp1, temp2);
					
					Devices[i].Partitions[j].PartitionSize 		:= 65536 * temp1 + temp2;

					temp1 := PartitionResult.StartSectorMajor;
					temp2 := PartitionResult.StartSectorMinor;
					FixBytes (temp1, temp2);

					Devices[i].Partitions[j].PartitionSectors 	:= 65536 * temp1 + temp2;

					aux1 := Devices[i].Partitions[j].PartitionSectors;
					aux2 := 0;
					k := 1;
					
					while ( k <= maxdriveletters ) and ( aux1 <> aux2 ) do
					begin
						DriveLetter.PhysicalDrive := chr(64 + k);
						GetInfoDriveLetter (DriveLetter);
						aux2 := DriveLetter.FirstDeviceSectorNumber;
						if Devices[i].Partitions[j].PartitionSectors = DriveLetter.FirstDeviceSectorNumber then
							Devices[i].Partitions[j].DriveAssignedToPartition := DriveLetter.PhysicalDrive;
						k := k + 1;
					end;
				end;

{-----------------------------------------------------------------------------}
write('Device ', i, ' extended partition ', DevicePartition.PrimaryPartition);
if Devices[i].Partitions[j].PartitionType = logical then
	writeln(' Partition ', j, ' is a logical partition.');
	writeln(' Drive letter: ', Devices[i].Partitions[j].DriveAssignedToPartition);
	writeln (' Partition size: ', Devices[i].Partitions[j].PartitionSize:0:0, ' sectors, or ', 
								((Devices[i].Partitions[j].PartitionSize)/2048):0:0, ' Mb.');
	writeln (' Initial sector: ', Devices[i].Partitions[j].PartitionSectors:0:0);
writeln;	
{-----------------------------------------------------------------------------}			
			
		end;
		
		i := i + 1;
	end;
end;

procedure PrintInfoAboutPartitions;
begin
	writeln;
	writeln('There are ', HowManyDevices, ' devices on your MSX.');
	
	for i := 1 to HowManyDevices do
	begin
		write('Device ', 	i, ' Slot ', Devices[i].DriverSlot, ' Segment ', 
						Devices[i].DriverSegment, ' LUN ', Devices[i].LUN, ' ');
		case Devices[i].DeviceType of
			Drive: 		begin
							write(' Drive-based driver. ');
							writeln(' Drive letter: ', Devices[i].DriveAssigned);
						end;
			Device: 	begin
							j := 1;
							write(' Device-based driver. ');
							while ( j <= maxpartitions ) and ( Devices[i].Partitions[j].PartitionNumber <> 0 ) do
							begin
								writeln;
								writeln(' Partition ', Devices[i].Partitions[j].PartitionNumber);
								case Devices[i].Partitions[j].PartitionType of
									primary	: writeln(' It''s a primary partition.');
									extended: writeln(' It''s a extended partition.');
									logical	: writeln(' It''s a logical partition.');
								end;
								writeln(' Drive letter: ', Devices[i].Partitions[j].DriveAssignedToPartition);
								writeln(' Partition size: ', Devices[i].Partitions[j].PartitionSize:0:0, ' bytes.');
								writeln(' First sector of partition: ', Devices[i].Partitions[j].PartitionSectors:0:0);
								j := j + 1;
							end;
						end;
			Floppy: 	write(' Floppy drive. ');
			RAMDisk: 	begin
							write(' RAM Disk. ');
							writeln;
							writeln(' Drive letter: ', Devices[i].DriveAssigned);
						end;
		end;
		writeln;
	end;
end;

BEGIN
(*	Detects if it's MSX-DOS 1, MSX-DOS 2 or Nextor. *)

	case DOSVEREnhancedDetection of
		0: 	begin
				writeln ('MSX-DOS 1 detected, so lsblk won''t run.');
				halt;
			end;
		1:  begin
				writeln ('MSX-DOS 2 detected, so lsblk won''t run.');
				halt;
			end;
	end;

	GatherInfoAboutPartitions;

	if paramcount = 0 then
	(*	Shows current information about zero allocation mode. *)
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
						'V': CommandLine(1);		(* Help 	*)
						'H': CommandLine(2);		(* Version 	*)
						'B': 	begin				(* Print the sizes in bytes. *)
								end;
								
						'D': 	begin				(* Show info about a specific partition. *)
								end;
								
						'F': 	begin				(* Shows the used filesystems too. *)
								end;
								
						'L': 	begin				(* Shows block devices as a list. *)
								end;
						
					end;
				end;
		end;
	end;	
END.

