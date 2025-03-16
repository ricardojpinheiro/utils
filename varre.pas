
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

type
	Upper = set of 'A'..'Z';
	Lower = set of 'a'..'z';

var
    MSXDOSVersao: TMSXDOSVersion;
    DriveStatus: TDriveStatus;
    DeviceDriver: TDeviceDriver;
    DriveLetter: TDriveLetter;
    DevicePartition: TDevicePartition;
    PartitionResult: TPartitionResult;
    RoutineDeviceDriver: TRoutineDeviceDriver;
    NextorDevices: THardwareDevices;
    MapDrive: TMapDrive;
    Character: char;
    i, j, k: byte;
    
    temtexto: boolean;
    
    TempString: TTinyString;

	LowerAlphabet: Lower;
	UpperAlphabet: Upper; 
	LINL40: byte absolute $F3AE;
	Data: array[0..7] of byte;

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

BEGIN
    Character := ' ';
	clrscr;

	writeln(LINL40);
	
	for i := 0 to ctMaxSlots - 1 do
		for j := 0 to CtMaxSecSlots - 1 do
		begin
		(*	Call a routine in a device driver *)
			regs.C 	:= ctCDRVR;
		(*	Driver slot number, from $F348 to $F348 + (4 * 4) *)
			regs.A 	:= MakeSlotNumber (i, j);
		(*	Driver segment number - $FF for ROM drivers. *)
			regs.B 	:= $FF;
		(*	Routine address - BTW, DEV_INFO ($4163). *)
			regs.DE := ctDEV_INFO;
		(*	Address of a 8 byte buffer with the input register values for DEV_INFO. *)
			regs.HL := Addr(Data);

			Data[0] := 0;	(*Register F*)
			Data[1] := i;	(*Register A: Device index (1 to 7).*)
			Data[2] := 0;	(*Register C*)
			Data[3] := 0;	(*Register B: Information to return - basic.*)
			Data[4] := 0;	(*Register E*)
			Data[5] := 0;	(*Register D*)
		(*	We didn't used HL registers because it doesn´t matter to this routine. *)

		(*	Here is where the magic begins. *)
			MSXBDOS ( regs );
			
		(*	If there aren't any errors... There is a Nextor kernel here. *)

			writeln ('Slot: ', i, ' Subslot: ', j, ' Slot: ', MakeSlotNumber (i, j), ' Error Code: ', regs.A); 

		end;
END.
