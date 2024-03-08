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
	maxpartitions 	= 16;
	maxdevices		= 8;

type
	DeviceData = record
		Device:	byte;

		(*	1: Drive-based driver. *)
		(*	2: Device-based driver. *)
		(*	3: Floppy disk. *)
		(*	4: RAM Disk. *)

		DeviceType: byte;

		(*	1: Primary partition. *)
		(*	2: Extended partition. *)
		(*	3: Logical partition. *)
	
		DriverSlot, DriverSegment, LUN: byte;
		ExtendedPartitionNumber: byte;
		PartitionType: array[1..maxpartitions] of byte;
		PartitionNumber: byte;
		PartitionSize: array[1..maxpartitions] of real;
	end;

var 
	Parameters:			TTinyString;
	DeviceDriver: 		TDeviceDriver;
	DriveLetter: 		TDriveLetter;
	DevicePartition: 	TDevicePartition;
	PartitionResult: 	TPartitionResult;
	Devices:			array[1..maxdevices] of DeviceData;
	c:					Char;
	i, j: 				byte;

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
	HowManyDevices, ErrorCodeInvalidDeviceDriver,
	ErrorCodeInvalidPartitionNumber: byte;
	ExtendedPartitionPerDevice, HowManyPrimaryPartitionsPerDevice, 
	HowManyLogicalPartitionsPerDevice: array[1..4] of byte;

begin
	FillChar(Devices, SizeOf ( Devices ), 0 );
	FillChar(Regs, SizeOf ( Regs ), 0 );

	(* 	Find how many devices are used in the MSX and 
		get information about them. *)

	HowManyDevices := 1;
	ErrorCodeInvalidDeviceDriver := 0;

	while ErrorCodeInvalidDeviceDriver <> ctIDRVR do
	begin
		DeviceDriver.DriverIndex := HowManyDevices;
		GetInfoDeviceDriver (DeviceDriver);
		ErrorCodeInvalidDeviceDriver := regs.A;

		writeln (' Device ', HowManyDevices, ' on your MSX.');

		Devices[HowManyDevices].Device := HowManyDevices;
		
		if DeviceDriver.DeviceOrDrive = 0 then
			Devices[HowManyDevices].DeviceType := 1 	(* Drive-based driver.	*)
		else
			Devices[HowManyDevices].DeviceType := 2; 	(* Device-based driver. *)

		with Devices[HowManyDevices] do
		begin
			DriverSlot 		:= DeviceDriver.DriverSlot;
			DriverSegment 	:= DeviceDriver.DriverSegment;
			LUN 			:= 1;
		end;

{-----------------------------------------------------------------------------}
case Devices[HowManyDevices].DeviceType of
	1: 	writeln (' Device ', HowManyDevices , ' has a drive-based driver.	');
	2: 	writeln (' Device ', HowManyDevices , ' has a device-based driver.	');
end;
{-----------------------------------------------------------------------------}
		
		HowManyDevices := HowManyDevices + 1;

	end;

	i := 1;
	while i <= HowManyDevices do
	begin

	(*	Some information which is common for each device. *)

		if Devices[i].DeviceType = 2 then
		begin
			DevicePartition.DriverSlot := Devices[i].DriverSlot;
			DevicePartition.DriverSegment := Devices[i].DriverSegment;
			DevicePartition.DeviceIndex := i;
			DevicePartition.LUN := Devices[i].LUN;
			DevicePartition.GetInfo := true;
		end;

	(*	If the device has a driver, then it would have partitions. Here goes
		an lousy effort to map primary (1) and extended (2) partitions. *)
			
		j := 0;
		
		while ( j <= 4 ) and ( ErrorCodeInvalidPartitionNumber <> ctIPART ) do
		begin
			j := j + 1;
			DevicePartition.PrimaryPartition 	:= j;
			DevicePartition.ExtendedPartition 	:= 0;
			GetInfoDevicePartition (DevicePartition, PartitionResult);
			ErrorCodeInvalidPartitionNumber 	:= regs.A;
			
			if ErrorCodeInvalidPartitionNumber <> ctIPART then
				case PartitionResult.PartitionType of
					1,4,6,14: 	begin
									Devices[i].PartitionType[j] := 1;
									Devices[i].PartitionSize[j] := 	(65536 - PartitionResult.PartitionSizeMinor) + 
																	(65536 * PartitionResult.PartitionSizeMajor);
								end;
					5: begin
							Devices[i].PartitionType[j] := 2;
							Devices[i].ExtendedPartitionNumber := DevicePartition.PrimaryPartition;
						end;
				end;

{-----------------------------------------------------------------------------}
write('Device ', i, ' partition ', j, '  ');
case Devices[i].PartitionType[j] of
	1: writeln('It''s a primary partition.	');
	2: writeln('It''s a extended partition.	');
end;
writeln ('Partition size: ', Devices[i].PartitionSize[j]:2:0);
writeln;	
{-----------------------------------------------------------------------------}			
			
		end;
		
		i := i + 1;
	end;

	(*	Now we must find all logical (3) partitions in the extended partition. *)

	i := 1;
	while ( i <= HowManyDevices ) and ( Devices[i].DeviceType = 2 ) do
	begin

	(*	Some information which is common for each device. *)

		DevicePartition.DriverSlot 			:= Devices[i].DriverSlot;
		DevicePartition.DriverSegment 		:= Devices[i].DriverSegment;
		DevicePartition.DeviceIndex 		:= i;
		DevicePartition.LUN 				:= Devices[i].LUN;
		DevicePartition.GetInfo 			:= true;
		DevicePartition.PrimaryPartition 	:= Devices[i].ExtendedPartitionNumber;

	(*	Here goes my lousy effort to map all logical (3) partitions. *)
			
		j := 0;
		
		while ( j <= maxpartitions ) or ( ErrorCodeInvalidPartitionNumber <> ctIPART ) do
		begin
			j := j + 1;
			DevicePartition.ExtendedPartition 	:= j;

{
writeln(Devices[i].ExtendedPartitionNumber);
writeln(DevicePartition.ExtendedPartition);
}
			GetInfoDevicePartition (DevicePartition, PartitionResult);
			ErrorCodeInvalidPartitionNumber 	:= regs.A;
			
			if ErrorCodeInvalidPartitionNumber <> ctIPART then
				if PartitionResult.PartitionType in [1,4,6,14] then
				begin
					Devices[i].PartitionType[j] := 3;
					Devices[i].PartitionSize[j] := SizeBytes(PartitionResult.PartitionSizeMajor, 
															PartitionResult.PartitionSizeMinor);
				end;

{-----------------------------------------------------------------------------}
write('Device ', i, ' extended partition ', DevicePartition.PrimaryPartition);
if Devices[i].PartitionType[j] = 3 then
	writeln(' Partition ', j, ' is a logical partition.');
	writeln (' Partition size: ', Devices[i].PartitionSize[j]:0:0, ' sectors, or ', 
								((Devices[i].PartitionSize[j])/2048):0:0, ' Mb.');
writeln;	
{-----------------------------------------------------------------------------}			
			
		end;
		
		i := i + 1;
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

	if paramcount = 0 then
	(*	Shows current information about zero allocation mode. *)
		GatherInfoAboutPartitions
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

