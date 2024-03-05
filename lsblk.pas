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

var 
	Parameters:			TTinyString;
	DeviceDrivers: 		array[1..8] of TDeviceDriver;
	DriveLetters:		array[1..8] of TDriveLetter;
	DevicePartitions: 	array[1..16] of TDevicePartition;
	PartitionsResult: 	array[1..16] of TPartitionResult;
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
	HowManyDevices, ErrorCodeInvalidDeviceDriver , ErrorCodeInvalidPartitionNumber: byte;
	ExtendedPartitionPerDevice, HowManyPrimaryPartitionsPerDevice, 
	HowManyLogicalPartitionsPerDevice: array[1..4] of byte;

begin
	FillChar(DeviceDrivers, SizeOf ( DeviceDrivers ), 0 );
	FillChar(Regs, SizeOf ( Regs ), 0 );

	(* 	Find how many devices are used in the MSX and 
		get information about them. *)

	HowManyDevices := 1;
	ErrorCodeInvalidDeviceDriver := 0;
	i := 1;
	
	while ErrorCodeInvalidDeviceDriver <> ctIDRVR do
	begin
		DeviceDrivers[HowManyDevices].DriverIndex := HowManyDevices;
		GetInfoDeviceDriver (DeviceDrivers[HowManyDevices]);
		ErrorCodeInvalidDeviceDriver := regs.A;

		writeln (' Device ', HowManyDevices, ' on your MSX.');

	(*	Get info about device partitions. *)
{	
		with DeviceDrivers[HowManyDevices] do
		begin
			DevicePartitions[i].DriverSlot := DriverSlot;
			DevicePartitions[i].DriverSegment := DriverSegment;
		end;
		
	(*	Find how many primary partitions does we have *)
		
		while ( i <= 4 ) and ( ErrorCodeInvalidPartitionNumber <> ctIPART ) do
		begin
			FillChar( Regs, SizeOf ( Regs ), 0 );
			writeln (i);
			DevicePartitions[i].PrimaryPartition := i;
			DevicePartitions[i].ExtendedPartition := 0;
			GetInfoDevicePartition (DevicePartitions[i], PartitionsResult[i]);
			ErrorCodeInvalidPartitionNumber := regs.A;
			i := i + 1;
		end;
		
		HowManyPrimaryPartitionsPerDevice[HowManyDevices] := i;

		i := 0;

		writeln(' There are ', HowManyPrimaryPartitionsPerDevice[HowManyDevices], 
		' partitions on device ', HowManyDevices);

}
		HowManyDevices := HowManyDevices + 1;
		i := i + 1;

	end;

{
	(*	Which partition is the extended one *)		
	
		while PartitionsResult[i].PartitionType <> 5 do
			
	
	(*	Find how many logical partitions does we have *)
		
		FillChar(Regs, SizeOf ( Regs ), 0 );
		HowManyLogicalPartitions[j] := 0;
		
		while ( regs.A <> ctIPART ) do
		begin
			FillChar (DevicePartition, SizeOf (DevicePartition), 0);
			FillChar (PartitionResult, SizeOf (PartitionResult), 0);
		
			GetInfoDevicePartition (DevicePartition, PartitionResult);
			
			HowManyLogicalPartitions[j] := HowManyLogicalPartitions[j] + 1;
		end;

	writeln (' Devices: ', HowManyDevices);
	for j := 1 to HowManyDevices do
	begin
		writeln (' Primary partitions in Device ', j, ': ', HowManyPrimaryPartitions[j]);
		writeln (' Extended partition in Device ', j, ': ', ExtendedPartition[j]);
		writeln (' Logical partitions in Device ', j, ': ', HowManyLogicalPartitions[j]);
	end;

	(* 	Get info about all drive letters. *)
{
	FillChar(DriveLetters, SizeOf ( DriveLetters ), 0 );
	FillChar(Regs, SizeOf ( Regs ), 0 );
	
	for i := 1 to 8 do
	begin
		DriveLetters[i].PhysicalDrive := chr(64 + i);
		
		GetInfoDriveLetter (DriveLetters[i]);
	end;
}

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

