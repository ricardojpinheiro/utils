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
            writeln (' MSXDOS2.SYS ', regs.D, '.', Decimal2Hexa(regs.E));
        end
        else
        begin
            writeln (' Nextor detected. ');
            writeln (' NEXTOR.SYS ', regs.D, '.', Decimal2Hexa(regs.E));
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
                (GetDriveSpaceInfo (Character, ctGetFreeSpace)):2:0 , ' Kb.');
    writeln (' Total space in drive ', Character, ': ', 
                (GetDriveSpaceInfo (Character, ctGetTotalSpace)):2:0 , ' Kb.');
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
        DriverIndex := nNextorSlotNumber;
        DriverSlot := 2;
        DriverSegment := $FF;
    end;

    GetInfoDeviceDriver (DeviceDriver);

    writeln('Error code = ', regs.A);

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
    Aux1, Aux2: real;
    Slot: byte;
    
begin
	write ('Slot (0-3): ');
	read (Slot);
	writeln;
    with DevicePartition do
    begin
        (* Driver Slot. *)
        DriverSlot := nNextorSlotNumber;
        
        (* Driver Segment. *)
        DriverSegment := $FF;
        
        (* Device Index. *)
        DeviceIndex := 1;
        
        (* LUN. *)
        LUN := 1;
        
        (* Get Info? *)
        GetInfo := true;
        
        (* Primary and Extended Partition. *)
        PrimaryPartition    := 1;
        ExtendedPartition   := 0;

        writeln (   ' Slot: ', DriverSlot, 
                    ' Segment: ', DriverSegment, 
                    ' Device: ', DeviceIndex,
                    ' LUN: ', LUN);

    end;
    
    GetInfoDevicePartition (DevicePartition, PartitionResult);
    
    writeln('regs.A = ', regs.A);
    writeln('regs.C = ', regs.C);
    
    with PartitionResult do
    begin
        writeln (' Partition type: ', PartitionType,': ', SPartitionType);
    
        Aux1 := PartitionSizeMajor;
        Aux2 := PartitionSizeMinor;
        FixBytes(Aux1, Aux2);

        writeln (' Partition size (Sectors): ', SizeBytes (Aux1, Aux2):0:0, ' sectors.');
        writeln (' Partition size (Mb): 	 ', round(int(SizeBytes (Aux1, Aux2) / 1048576)), ' Mb. ');

        Aux1 := StartSectorMajor;
        Aux2 := StartSectorMinor;
        FixBytes(Aux1, Aux2);

        writeln (' Start sector: ',  SizeBytes(Aux1, Aux2):0:0);
    end;
end;

procedure CDRVRExample;
var
	i, j, k: integer;
	a, b: byte;
	c: char;
	RealData: real;
	Information: array[0..63] of byte;
	Data: array[0..7] of byte;
	LUNData: array [0..11] of byte;
	
begin
(*	DEV_INFO. *)

	writeln('DEV_INFO:');
	write (' Which device do you want to get info? (1-7): ');
	readln(b);

	for j := 0 to 3 do
	begin
		FillChar(Data, 			SizeOf (Data), 			0);
		FillChar(Information, 	SizeOf (Information), 	chr(32));

		regs.C 	:= ctCDRVR;
		regs.A 	:= nNextorSlotNumber;
		regs.B 	:= $FF;
		regs.DE := ctDEV_INFO;
		regs.HL := Addr(Data);

		Data[0] := 0;	(*F*)
		Data[1] := b;	(*A*)
		Data[2] := 0;	(*C*)
		Data[3] := j;	(*B*)
		Data[4] := 0;	(*E*)
		Data[5] := 0;	(*D*)
		Data[6] := lo(Addr(Information));	(*L*)
		Data[7] := hi(Addr(Information));	(*H*)

		MSXBDOS ( regs );

		if j = 0 then
		begin
			writeln('Device ', b);
			writeln('Number of logical units: ',	Information[0]);
			writeln('Device features flags: ', 		Information[1]);
			writeln('Information type: ', Data[3], ' regs.A: ', regs.A);
			writeln('Regs.B: ', regs.B, ' Regs.C: ', regs.C);
			writeln('Regs.DE: ', regs.DE, ' Regs.HL: ', regs.HL);
			writeln('Value of AF returned by the routine (Regs.IX): ', regs.IX);
		end;
		case j of
			0: write('Basic information: ');
			1: write('Manufacturer name string: ');
			2: write('Device name string: ');
			3: write('Serial number string: ');
		end;
		for i := 0 to 63 do 
			write(chr(Information[i]));
		writeln;
	end;
(*	LUN_INFO. *)

	writeln('LUN_INFO:');

	FillChar(Data, 			SizeOf (Data), 			0);
	FillChar(LUNData, 		SizeOf (LUNData), 		0);
	FillChar(Information, 	SizeOf (Information), 	chr(32));

	writeln (' Which device do you want to get information? (1 to 7)');
	c := readkey;
	val (c, i, k);

	writeln (' Which LUN do you want to get information?');
	c := readkey;
	val (c, j, k);

	regs.A := nNextorSlotNumber;
	regs.B := $FF;
	regs.DE := ctLUN_INFO;
	regs.HL := Addr(Data);
	regs.C 	:= ctCDRVR;

	Data[0] := 0;	(*F*)
	Data[1] := i;	(*A*)
	Data[2] := 0;	(*C*)
	Data[3] := j;	(*B*)
	Data[4] := 0;	(*E*)
	Data[5] := 0;	(*D*)
	Data[6] := lo(Addr(LUNData));	(*L*)
	Data[7] := hi(Addr(LUNData));	(*H*)

	MSXBDOS ( regs );

	writeln('Device ', i);
	if regs.A = 0 then
	begin
		write('Medium type: ');
		case LUNData[0] of
			0: 		write('Block device.');
			1: 		write('CD or DVD reader or recorder.');
			else 	write('Unused (reserved for future use).');
		end;
		writeln;

		RealData := 256 * LUNData[2] + LUNData[1];
		writeln('Sector size: ', RealData:3:0);

		k := LUNData[6];
		RealData :=	16777216 * k;
		k := LUNData[5];
		RealData := RealData + 65536 * k;
		k := LUNData[4];
		RealData := RealData + 256 * k;
		k := LUNData[3];
		RealData := RealData + k;

		writeln('Total number of available sectors: ', RealData:6:0);
		writeln('LUN feature flags: ', LUNData[7]);
		RealData := 256 * LUNData[9] + LUNData[8];
		writeln('Number of cylinders: ', RealData:3:0);
		writeln('Number of heads: ', LUNData[10]);
		writeln('Number of sectors per track: ', LUNData[11]);
	end
	else
		writeln('Error, device or LUN not available.');
{
	FillChar(Data, 			SizeOf (Data), 			0);
	FillChar(Information, 	SizeOf (Information), 	chr(32));
		
	writeln('DEV_STATUS: ');
	regs.A := 1;
	regs.B := $FF;
	regs.DE := ctDEV_STATUS;
	regs.HL := Addr(Data);
	regs.C 	:= ctCDRVR;

	for i := 1 to 7 do
	begin
		Data[0] := 0;	(*F*)
		Data[1] := i;	(*A*)
		Data[2] := 0;	(*C*)
		Data[3] := 1;	(*B*)
		Data[4] := 0;	(*E*)
		Data[5] := 0;	(*D*)
		Data[6] := lo(Addr(LUNData));	(*L*)
		Data[7] := hi(Addr(LUNData));	(*H*)

		MSXBDOS ( regs );
		
		writeln (' Device ', Data[1], ' LUN ', Data[3]);
		case LUNData[0] of
			0: 	 writeln (Regs.A, ' Device or logical unit isn''t available, or the device or LUN supplied is invalid.');
			1: 	 writeln (Regs.A, ' Device or logical unit is available, not changed since the last status request.');
			2: 	 writeln (Regs.A, ' Device or logical unit is available, changed since the last status request.');
			3: 	 writeln (Regs.A, ' Device or logical unit is available, not possible to determine if changed or not.');
			else writeln (Regs.A, ' Who cares.');
		end;
	end;
}
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
        Slot := nNextorSlotNumber;
        
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
                SizeBytes(PartitionResult.StartSectorMinor, PartitionResult.StartSectorMajor):0:0);
    end;
    SetMAPDRV ( MapDrive,   PartitionResult.StartSectorMajor, 
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

var
	Hexa: TBinNumber;
	i: byte;

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
        writeln(' 8 - CDRVR (Call a routine in a device driver).');
        writeln(' 9 - MAPDRV (Map a drive letter to a driver and device).');
        writeln(' A - Z80MODE (Enable or disable the Z80 access mode for a driver).');
        writeln(' B - Information about the lib and this program');
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
            '8': CDRVRExample;
            '9':    begin
                        GPARTExample;
                        MAPDRVExample;
                    end;
            'A': Z80MODEExample;
            'B':    begin
                        writeln (' This code was written to have some examples of how we can use the Nextor'); 
                        writeln (' function calls. There are some function calls that wasn''t implemented, ');
                        writeln (' as FOUT, ZSTROUT, RDDRW, WRDRV and GETCLUS. The reasons may vary, such  ');
                        writeln (' as lack of interest or the lack of need: FOUT and ZSTROUT, for example, ');
                        writeln (' can even be implemented, but there are some routines which are as good  ');
                        writeln (' as these Nextor function calls. So, there were implemented only the most');
                        writeln (' important Nextor function calls. If you want to write the lost Nextor   ');
                        writeln (' function calls, be my guest. ');
                    end;
            'F': exit;
        end;
        Character := readkey;
    end;
END.
