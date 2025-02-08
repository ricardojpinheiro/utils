
{
   varre.pas
   
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

program Varredura;

{$i d:types.pas}
{$i d:msxdos.pas}
{$i d:msxdos2.pas}
{$i d:nextor.pas}

var
    MSXDOSVersao: TMSXDOSVersion;
    DriveStatus: TDriveStatus;
    DeviceDriver: TDeviceDriver;
    DriveLetter: TDriveLetter;
    DevicePartition: TDevicePartition;
    PartitionResult: TPartitionResult;
    RoutineDeviceDriver: TRoutineDeviceDriver;
    MapDrive: TMapDrive;
    Character: char;

function Readkey : char;
var
    bt: integer;
    qqc: byte absolute $FCA9;
begin
     readkey := chr(0);
     qqc := 1;
     Inline($f3/$fd/$2a/$c0/$fc/$DD/$21/$9F/00     
            /$CD/$1c/00/$32/bt/$fb);
     readkey := chr(bt);
     qqc := 0;
end;

procedure GDRVRExample;
var
	i, j: byte;
	c: char;
	
begin
    FillChar(DeviceDriver, SizeOf ( DeviceDriver ), 0 );

	for i := 1 to 7 do
	begin
		with DeviceDriver do
		begin
			DriverIndex 	:= i;
			DriverSlot 		:= nNextorSlotNumber;
			DriverSegment 	:= $FF;
		end;

		c := readkey;

		GetInfoDeviceDriver (DeviceDriver);

		If regs.A = $B6 then
			writeln ('There isn''t a device number ', i)
		else
			begin
				writeln;
				with DeviceDriver do
				begin
					writeln (' Driver Index: ', DriverIndex);
					writeln (' Driver Slot: ', DriverSlot);
					writeln (' Driver Segment: ', DriverSegment);
					writeln (' How many assigned drive letters: ', DriveLettersAtBootTime);
					writeln (' First drive letter: ', FirstDriveLetter);
					if NextorOrMSXDOSDriver = 0 then
						writeln (' It''s a MSX-DOS driver.')
					else
						writeln (' It''s a Nextor driver.');
					if HasDRVCONFIG = 0 then
						writeln (' This driver implements the DRV_CONFIG routine.')
					else
						writeln (' This driver doesn''t implements the DRV_CONFIG routine.');
					if DeviceOrDrive = 0 then
						writeln (' This is a drive-based driver.')
					else
						writeln (' This is a device-based driver.');
					writeln (' Driver number: ' , DriverMainNumber, '.' 
												, DriverSecondaryNumber, '.' 
												, DriverRevisionNumber);
					writeln (' Driver Name: ', DriverName);
				end;
		end;
	end;
end;

BEGIN
    Character := ' ';
	clrscr;
	writeln(' Varre os dispositivos no MSX e aponta quais estao disponiveis. ');
	GDRVRExample;
END.
