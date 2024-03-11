{
   nextdemo.pas
   
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

program Nextor_Demo;

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

procedure DOSVEREnhancedExample;
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
		writeln (' MSX-DOS 1 detected. ')
	else
		if regs.IX = 0 then
		begin
			writeln (' MSX-DOS 2 detected. ');
			writeln (' MSXDOS2.SYS ', regs.D, '.', regs.E);
		end
		else
		begin
			writeln (' Nextor detected. ');
			writeln (' NEXTOR.SYS ', regs.D, '.', regs.E);
		end;
	
end;

procedure DSPACEExample;
var 
	i: byte;
	
begin
	writeln;
	writeln (' Which drive do you want to get info? ');
	Character := upcase(readkey);
	writeln (' Free space in drive ', Character, ': ', 
				(GetDriveSpaceInfo (Character, ctGetFreeSpace)):2:2 , ' kb.');
	writeln (' Total space in drive ', Character, ': ', 
				(GetDriveSpaceInfo (Character, ctGetTotalSpace)):2:2 , ' Kb.');
end;

procedure LOCKExample;
var
	i: byte;
begin
	writeln;
	writeln (' Which drive do you want to get and set lock info? ');
	Character := upcase(readkey);
		if GetLockStatus (Character) = 0 then
			writeln (' Drive ', Character, ' is unlocked')
		else
			writeln (' Drive ', Character, ' is locked. ');

		if SetLockStatus (Character, true) = 0 then
			writeln (' Now Drive ', Character, ' is unlocked')
		else
			writeln (' Now Drive ', Character, ' is locked. ');
end;

procedure RALLOCExample;
var 
	i: byte;
	Status: TTinyString;

begin
	writeln;
	writeln (' Which drive do you want to get zero allocation status? ');
	Character := upcase(readkey);
	i := ord(Character) - 65;
	
	writeln;	
	writeln('Get Ralloc Status: ');	

	GetRALLOCStatus (DriveStatus);
	
	if DriveStatus[i] = 0 then
		Status := 'OFF'
	else
		Status := 'ON';

	write ('Drive ', Character , ': ', Status);

	writeln;
	writeln('Set Ralloc Status: ');
	
	writeln;
	writeln (' Do you want to set zero allocation status for this drive? (Y/N)');
	Character := upcase(readkey);

	if Character = 'Y' then
		DriveStatus[i] := 1
	else
		DriveStatus[i] := 0;

	SetRALLOCStatus (DriveStatus);

	writeln;
	writeln('Get All Ralloc Status: ');
	GetRALLOCStatus (DriveStatus);

	for i := 0 to 7 do
	begin
		write ('Drive ',chr(65 + i), ': ');
		if DriveStatus[i] = 0 then
			writeln('OFF')
		else
			writeln('ON');
	end;
end;

procedure GDRVRExample;
begin
	FillChar(DeviceDriver, SizeOf ( DeviceDriver ), 0 );

	with DeviceDriver do
	begin
		DriverIndex := 1;
		DriverSlot := 0;
		DriverSegment := 0;
	end;
	
	GetInfoDeviceDriver (DeviceDriver);

	writeln('regs.A = ', regs.A);

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
		writeln (' Driver number: '	, DriverMainNumber, '.' 
									, DriverSecondaryNumber, '.' 
									, DriverRevisionNumber);
		write (' Driver Name: ', DriverName);
	end;
end;

procedure GDLIExample;
begin
	writeln;
	writeln (' Which drive do you want to get information? ');
	DriveLetter.PhysicalDrive := upcase(readkey);
	
	GetInfoDriveLetter (DriveLetter);
	
	with DriveLetter do
	begin
		writeln(' Physical Drive: ', PhysicalDrive);
		write(' Drive Status: ');
		case DriveStatus of
			0: writeln ('Unassigned.'); 
			1: writeln ('Assigned to a storage device attached to a Nextor or MSX-DOS driver.');
			2: writeln ('Unused.');
			3: writeln ('A file is mounted in the drive.');
			4: writeln ('Assigned to the RAM disk.');
		end;		
		writeln(' Driver Slot: ', DriverSlot);
		writeln(' Driver Segment: ', DriverSegment);
		writeln(' Relative Drive Number: ', RelativeDriveNumber);
		writeln(' Device Index: ', DeviceIndex);
		writeln(' LUN: ', LUN);
		writeln(' First Device Sector Number: ', FirstDeviceSectorNumber:0:0);
	end;
	
end;

procedure GPARTExample;
var 
	SizeReal: real;
	SizeInteger: integer;
	
begin
	with DevicePartition do
	begin
		(* Driver Slot. *)
		DriverSlot := 1;
		
		(* Driver Segment. *)
		DriverSegment := 255;
		
		(* Device Index. *)
		DeviceIndex := 1;
		
		(* LUN. *)
		LUN := 1;
		
		(* Get Info? *)
		GetInfo := true;
		
		(* Primary and Extended Partition. *)
		PrimaryPartition 	:= 2;
		ExtendedPartition 	:= 1;

		writeln (	' Slot: ', DriverSlot, 
					' Segment: ', DriverSegment, 
					' Device: ', DeviceIndex,
					' LUN: ', LUN);

	end;
	
	GetInfoDevicePartition (DevicePartition, PartitionResult);
	
	writeln('regs.A = ', regs.A);
	
	with PartitionResult do
	begin
		writeln (' Partition type: ', PartitionType,': ', SPartitionType);
		writeln (' Start sector: ',  SizeBytes(StartSectorMajor, StartSectorMinor):0:0);
		SizeReal := SizeBytes (PartitionSizeMajor, PartitionSizeMinor);
		SizeInteger := round(int(SizeReal / 2048));
		writeln (' Partition size: ', SizeReal:0:0, ' sectors.');
		writeln (' Partition size: ', SizeInteger, ' Mb. ');
	end;

end;

procedure MAPDRVExample;
begin
	with MapDrive do
	begin
		(* Physical Drive. For instance, drive B. *)
		PhysicalDrive := 'B';
		
		(* Map drive using specific data. *)
		Action := ctMapDriveSpecificData;
		
		(* File mount = 0. *)
		FileMount := 0;

		(* Slot 1. *)
		Slot := 1;
		
		(* Segment 255.*)
		Segment := 255;
		
		(* Device 1. *)
		Device := 1;
		
		(* LUN 1. *)
		LUN := 1;

		writeln (' Drive ', PhysicalDrive, ' will be mapped using specific data.');
		writeln (' It''ll be mapped in a device which slot is ', Slot, ' and Segment is ', Segment, '.');
		writeln (' The Device is ', Device, ' and the LUN is ', LUN);
		writeln (' It maps based on the information given by GPART function call, which is ');
		writeln (' the start sector of the device. By the way: ', 
				((65536 - PartitionResult.StartSectorMinor) + 
				(65536 * PartitionResult.StartSectorMajor)));
	end;
	SetMAPDRV ( MapDrive, 	PartitionResult.StartSectorMajor, 
							PartitionResult.StartSectorMinor ); 
end;

procedure Z80MODEExample;

	function msx_version: byte;
	var 
		version:    byte;
	begin
	  inline($3e/$80/              { LD A,&H80        }
			 $21/$2d/$00/          { LD HL,&H002D     }
			 $cd/$0c/$00/          { CALL &H000C      }
			 $32/version/          { LD (VERSIE),A    }
			 $fb);                 { EI               }
	  msx_version := version + 1;
	end;

begin
	if msx_version = 4 then
	begin
		writeln (' Get Z80 access mode status for a driver: ');
		writeln (' Driver slot: 1');
		writeln (' Current Z80 access mode: ', GetZ80AccessMode (1));

		writeln (' Set Z80 access mode status for a driver: ');
		writeln (' Driver slot: 1');
		writeln (' Current Z80 access mode: ', SetZ80AccessMode (1, true));
	end
	else
		writeln (' Sorry, this function call only runs in MSX Turbo-Rs.');
end;

BEGIN
	Character := ' ';
    while (Character <> 'F') do
    begin
        clrscr;
        writeln(' Nextor routines demo program: ');
        writeln(' Choose your weapon: ');
        writeln(' 1 - DOSVER Enhanced (Apps can detect if it''s MSX-DOS or Nextor).');
        writeln(' 2 - RALLOC (Get/set reduced allocation information mode vector).');
        writeln(' 3 - DSPACE (Get drive space information).');
        writeln(' 4 - LOCK (Lock/unlock a drive, or get lock state for a drive).');
        writeln(' 5 - GDRVR (Get information about a device driver).');
        writeln(' 6 - GDLI (Get information about a drive letter).');
        writeln(' 7 - GPART (Get information about a device partition).');
        writeln(' 8 - MAPDRV (Map a drive letter to a driver and device).');
        writeln(' 9 - Z80MODE (Enable or disable the Z80 access mode for a driver).');
        writeln(' A - Information about the lib and this program');
        writeln(' F - End.');
        Character := upcase(readkey);
        writeln;
        case Character of 
            '1': DOSVEREnhancedExample;
            '2': RALLOCExample; 
            '3': DSPACEExample;
            '4': LOCKExample;
            '5': GDRVRExample;
            '6': GDLIExample;
            '7': GPARTExample;
            '8': 	begin
						GPARTExample;
						MAPDRVExample;
					end;
            '9': Z80MODEExample;
            'A': 	begin
						writeln (' This code was written to have some examples of how we can use the Nextor'); 
						writeln (' function calls. There are some function calls that wasn''t implemented, ');
						writeln (' as FOUT, ZSTROUT, RDDRW, WRDRV, CDRVR and GETCLUS. The reasons may vary,');
						writeln (' such as lack of interest or the lack of need: FOUT and ZSTROUT, for ');
						writeln (' example, can even be implemented, but there are some routines which are');
						writeln (' as good as these Nextor function calls. So, there were implemented inly');
						writeln (' the most important Nextor function calls. If you want to write the lost ');
						writeln (' Nextor function calls, be my guest. ');
					end;
            'F': exit;
        end;
        Character := readkey;
    end;
END.
