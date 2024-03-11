(*<nextor.pas>
 * Nextor function call structures definitions and functions.
 * CopyLeft (c) 2024 by Ricardo Jurczyk Pinheiro.
 *)

(**
  *
  * $Id: nextor.pas 98 2024-02-17 11:16:16Z rjpinheiro $
  * $Author: rjpinheiro $
  * $Date: 22024-02-17 14:16:16 +0000 (Sat, 17 Feb 2024) $
  * $Revision: 98 $
  * $HeadURL: file:///svn/p/oldskooltech/code/msx/trunk/msxdos/pascal/nextor.pas $
  *)

(*
 * This module depends on folowing include files (respect the order):
 * - types.pas;
 * - msxdos.pas;
 * - msxdos2.pas;
 *)

(*
 * Nextor function call list - Official function names.
 * Thanks to Nextor 2.1 Programmers Reference at:
 * https://github.com/Konamiman/Nextor/blob/v2.1/docs/Nextor%202.1%20Programmers%20Reference.md
 *)

const
    ctFOUT      = $71; (* FOUT routine. Barely implemented.     *)
    ctZSTROUT   = $72; (* ZSTROUT routine. Barely implemented.  *)
    ctRDDRV     = $73; (* RDDRV routine. Not implemented.       *)
    ctWRDRV     = $74; (* WRDRV routine. Not implemented.       *)
    ctRALLOC    = $75; (* RALLOC routine.                       *)
    ctDSPACE    = $76; (* DSPACE routine.                       *)
    ctLOCK      = $77; (* LOCK routine.                         *)
    ctGDRVR     = $78; (* GDRVR routine.                        *)
    ctGDLI      = $79; (* GDLI routine.                         *)
    ctGPART     = $7A; (* GPART routine.                        *)
    ctCDRVR     = $7B; (* CDRVR routine. Not implemented.       *)
    ctMAPDRV    = $7C; (* MAPDRV  routine.                      *)
    ctZ80MODE   = $7D; (* Z80MODE routine.                      *)
    ctGETCLUS   = $7E; (* GETCLUS routine. Not implemented.     *)

    ctGetFastStroutMode         =   $00;
    ctSetFastStroutMode         =   $01;
    ctDisableFastStroutMode     =   $00;
    ctEnableFastStroutMode      =   $01;
    ctGetRallocStatus           =   $00;
    ctSetRallocStatus           =   $01;
    ctGetFreeSpace              =   $00;
    ctGetTotalSpace             =   $01;
    ctGetLockStatus             =   $00;
    ctSetLockStatus             =   $01;
    ctLockDrive                 =   $FF;
    ctUnlockDrive               =   $00;
    ctROMDrivers                =   $FF;
    ctUnmapDrive                =   $00;
    ctMapDriveDefaultState      =   $01;
    ctMapDriveSpecificData      =   $02;
    ctMountFileInTheDrive       =   $03;
    ctAutomaticMountType        =   $00;
    ctReadOnlyMountType         =   $01;
    ctGetCurrentZ80AccessMode   =   $00;
    ctSetZ80AccessMode          =   $01;
    ctDisableZ80AccessMode      =   $00;
    ctEnableZ80AccessMode       =   $FF;

    ctICLUS         = $B0; (* Invalid cluster number or sequence.   *)
    ctBFSZ          = $B1; (* Bad file size.                        *)
    ctFMNT          = $B2; (* File is mounted.                      *)
    ctPUSED         = $B3; (* Partition is already in use.          *)
    ctIPART         = $B4; (* Invalid partition number.             *)
    ctIDEVL         = $B5; (* Invalid device or LUN.                *)
    ctIDRVR         = $B6; (* Invalid device driver.                *)
    
type
    TBinNumber  = array [0..7] of byte;
    TDriveStatus = TBinNumber;

    TDriveLetter = record
        PhysicalDrive: char;
        DriveStatus, DriverSlot, DriverSegment,
        RelativeDriveNumber, DeviceIndex, LUN: byte;
        FirstDeviceSectorNumber: real;
    end;
    
    TDeviceDriver = record
        DriverIndex, DriverSlot, DriverSegment, DriveLettersAtBootTime: byte;
        FirstDriveLetter: char;
        NextorOrMSXDOSDriver, HasDRVCONFIG, DeviceOrDrive, 
        DriverMainNumber, DriverSecondaryNumber, DriverRevisionNumber: byte;
        DriverName: string[32];
    end;
    
    TDevicePartition = record
        DriverSlot, DriverSegment, DeviceIndex, LUN: byte;
        GetInfo: boolean;
        PrimaryPartition, ExtendedPartition: byte;
    end;

    TPartitionResult = record
        PartitionType: byte;
        SPartitionType: string[32];
        StartSectorMajor, StartSectorMinor: integer;
        PartitionSizeMajor, PartitionSizeMinor: integer;
    end;
    
    TMapDrive = record
        PhysicalDrive: char;
        (*  0: Unmap the drive                                  *)
        (*  1: Map the drive to its default state               *)
        (*  2: Map the drive by using specific mapping data     *)
        (*  3: Mount a file in the drive.                       *)
        Action, FileMount, Slot, Segment, Device, LUN, 
        StartSectorMinor, StartSectorMajor: byte;
    end;
        
    TParams = record
        Slot, Segment, Device, LUN: byte;
        StartSectorMinor, StartSectorMajor: integer;
    end;

var
    regs: TRegs;

function GetNextorErrorCode (ErrorCode: byte): TShortString;
var
    temp: TShortString;
begin
    str(ErrorCode, temp);
    case ErrorCode of
        ctIDRVR: GetNextorErrorCode := ' Invalid device driver.';
        ctIDEVL: GetNextorErrorCode := ' Invalid device or LUN.';
        ctIPART: GetNextorErrorCode := ' Invalid partition number.';
        ctPUSED: GetNextorErrorCode := ' Partition is already in use.';
        ctFMNT:  GetNextorErrorCode := ' File is mounted. ';
        ctBFSZ:  GetNextorErrorCode := ' Bad file size. ';
        ctICLUS: GetNextorErrorCode := ' Invalid cluster number or sequence. ';
        else GetNextorErrorCode := temp;
    end;
end;

function Power (x, y: integer): integer;
var
    i, j: byte;
begin
    j := 1;
    for i := 1 to y do
        j := j * x;
    Power := j;
end;

function Binary2Decimal(Binary: TBinNumber):integer;
var
    i: byte;
    x: integer;
begin
    x := 0;
    for i := 0 to 7 do
        x := x + Binary[i] * Power(2, 7 - i);
    Binary2Decimal := x;
end;

procedure Decimal2Binary(x: integer; var Binary: TBinNumber);
var
    i: byte;
begin
    i := 0;
    FillChar(Binary, sizeof(Binary), 0);
    repeat
        if (x mod 2 = 0) then
            Binary[i] := 0
        else
            Binary[i] := 1;
        x := x div 2;
        i := i + 1;
    until x = 0;
end;

function SizeBytes (Major, Minor: Integer): real;
begin
	SizeBytes := ((Major * 128) + (Minor / 512)) * 512;
end;

procedure GetRALLOCStatus ( var DriveRalloc: TDriveStatus );
begin
    FillChar ( regs, SizeOf( regs ), 0 );
    FillChar ( DriveRalloc, SizeOf ( DriveRalloc ), 0 );
    
    regs.A := ctGetRallocStatus;
    regs.C := ctRALLOC;
    
    MSXBDOS ( regs ); 
    Decimal2Binary (regs.HL, DriveRalloc); 
end;

procedure SetRALLOCStatus ( var DriveRalloc: TDriveStatus );
begin
    FillChar( regs, SizeOf( regs ), 0 );
     
    regs.A := ctSetRallocStatus;
    regs.C := ctRALLOC;
    regs.HL := Binary2Decimal (DriveRalloc);

    MSXBDOS ( regs ); 
end;

function GetDriveSpaceInfo ( DriveLetter: char; FreeOrTotalSpace: byte): real;
var
    temp1, temp2: real;

begin
    FillChar( regs, SizeOf( regs ), 0 );

    (* Nextor routine. *)
    regs.C := ctDSPACE;
    
    (* Drive letter - 0 is the default drive letter. *)
    regs.E := ord (DriveLetter) - 64;
    
    (* Free space or total space. *)
    regs.A := FreeOrTotalSpace;
    
    MSXBDOS ( regs );

	temp1 := maxint + regs.DE;
	temp2 := maxint + regs.HL;
	
    GetDriveSpaceInfo := temp1 + temp2;
end;

function GetLockStatus ( DriveLetter: char): byte;
begin
    FillChar( regs, SizeOf( regs ), 0 );

    (* Nextor routine. *)
    regs.C := ctLOCK;
    
    (* Drive letter - 0 is A: drive. *)
    regs.E := ord (DriveLetter) - 65;
    
    (* Get lock status. *)
    regs.A := ctGetLockStatus;
    
    MSXBDOS ( regs );

    (* Current lock status. *)
    GetLockStatus := regs.B;
end;

function SetLockStatus ( DriveLetter: char; LockOrUnlock: boolean): byte;
begin
    FillChar( regs, SizeOf( regs ), 0 );

    (* Nextor routine. *)
    regs.C := ctLOCK;
    
    (* Drive letter - 0 is A: drive. *)
    regs.E := ord (DriveLetter) - 65;
    
    (* Set lock status. *)
    regs.A := ctSetLockStatus;
    
    (* True: Lock; False: Unlock. *)
    if LockOrUnlock then
        regs.B := ctLockDrive
    else
        regs.B := ctUnlockDrive;
    
    MSXBDOS ( regs );

    (* Current lock status. *)
    SetLockStatus := regs.B;
    
end;

procedure GetInfoDeviceDriver (var DeviceDriver: TDeviceDriver);
var
    Data: string[64];
    i: byte;
    
begin
    FillChar( regs, SizeOf( regs ), 0 );

    (* Nextor routine. *)
    regs.C := ctGDRVR;
    
    with DeviceDriver do
    begin
        (* Driver Index. *)
        regs.A := DriverIndex;
    
        (* if Driver index is 0, should specify slot and segment. *)
    
        if DriverIndex = 0 then
        begin
            regs.D := DriverSlot;
            regs.E := DriverSegment;
        end;
    
        (* Pointer to 64 byte data buffer. *)
        regs.HL := Addr (Data);
    
        (* Make it so.*)
        MSXBDOS ( regs );

        (* Let's find all data. *)
        DriverSlot              := Mem[regs.HL];
        DriverSegment           := Mem[regs.HL + 1];
        DriveLettersAtBootTime  := Mem[regs.HL + 2];
        FirstDriveLetter        := chr(Mem[regs.HL + 3] + 65);
        NextorOrMSXDOSDriver    := Mem[regs.HL + 4] div 128;
        HasDRVCONFIG            := Mem[regs.HL + 4] mod 4;
        DeviceOrDrive           := Mem[regs.HL + 4] mod 2;
        DriverMainNumber        := Mem[regs.HL + 5];
        DriverSecondaryNumber   := Mem[regs.HL + 6];
        DriverRevisionNumber    := Mem[regs.HL + 7];

        for i := 8 to 40 do
            DriverName[i - 7]   := chr(Mem[regs.HL + i]);
        DriverName[0] := chr(sizeof(DriverName));
    end;
end;

procedure GetInfoDriveLetter (var DriveLetter: TDriveLetter);
var
    Data: string[64];
    i: byte;

begin
    FillChar( regs, SizeOf( regs ), 0 );

    (* Nextor routine. *)
    regs.C := ctGDLI;
    
    with DriveLetter do
    begin
        (* Driver Index. *)
        regs.A := (ord(upcase(PhysicalDrive)) - 65);

        (* Pointer to 64 byte data buffer. *)
        regs.HL := Addr (Data);
    
        (* Make it so.*)
        MSXBDOS ( regs );

        (* Let's find all data. *)
        DriveStatus             := Mem[regs.HL];
        DriverSlot              := Mem[regs.HL + 1];
        DriverSegment           := Mem[regs.HL + 2];
        RelativeDriveNumber     := Mem[regs.HL + 3];
        DeviceIndex             := Mem[regs.HL + 4];
        LUN                     := Mem[regs.HL + 5];

        FirstDeviceSectorNumber := 16777216 * Mem[regs.HL + 9] +
                                      65536 * Mem[regs.HL + 8] +
                                        256 * Mem[regs.HL + 7] +
                                              Mem[regs.HL + 6];
    end;
end;

procedure GetInfoDevicePartition (DevicePartition: TDevicePartition; 
                                 var PartitionResult: TPartitionResult);
begin
    FillChar( regs, SizeOf( regs ), 0 );
    
    (* ctGPART. *)
    regs.C := ctGPART;
    
    with DevicePartition do
    begin
        (* Driver Slot. *)
        regs.A := DriverSlot;
        
        (* Driver Segment. *)
        regs.B := DriverSegment;
        
        (* Device Index. *)
        regs.D := DeviceIndex;
        
        (* LUN. *)
        regs.E := LUN;
        
        (* Get info? *)
        if GetInfo then
            regs.H := 0
        else
            regs.H := 128;
        
        (* Primary partition. *)
        regs.H := regs.H + PrimaryPartition;
        
        (* Extended partition. *)
        regs.L := ExtendedPartition;
    end;
    
    (*  Make it so. *)
    MSXBDOS ( regs );
    
    with PartitionResult do
    begin
        (* Partition type. *)
        PartitionType := regs.B;
        
        (* Partition type - string. *)
        case PartitionType of
            0:      SPartitionType := 'Partition doesn''t exist.';
            1:      SPartitionType := ' FAT12.';
            4:      SPartitionType := ' FAT16 less than 32 Mb.';
            5:      SPartitionType := ' Extended.';
            6:      SPartitionType := ' FAT16 (CHS).';
            14:     SPartitionType := ' FAT16 (LBA).';
            else    SPartitionType := ' Nevermind.';
        end;
        
        (* Start sector.*)
        StartSectorMajor := regs.HL;
        StartSectorMinor := regs.DE;
        
        (* Partition size in sectors. *)
        PartitionSizeMajor := regs.IX;
        PartitionSizeMinor := regs.IY;

    end;
end;

procedure SetMAPDRV (   MapDrive: TMapDrive; 
                        StartSectorMajor, StartSectorMinor: integer );
var
    Params: TParams;

begin
    FillChar( regs, SizeOf( regs ), 0 );
    FillChar( Params, SizeOf( Params ), 0 );

    with MapDrive do
    begin
        (*  Physical drive. *)
        regs.A := ord(upcase(PhysicalDrive)) - 65;
        
        (*  Action: Map the drive using specific mapping data. *)
        regs.B := Action;
                
        (* File mount type. *)
        regs.D := FileMount;

        (*  Driver slot number. *)
        Params.Slot := Slot;

        (*  Driver segment number. *)
        Params.Segment := Segment;

        (*  Device. *)
        Params.Device := Device;
            
        (*  Logical Unit Number. *)
        Params.LUN := LUN;
    end;    

    (*  Start Sector Major and Minor. *)
    Params.StartSectorMinor := StartSectorMinor;
    Params.StartSectorMajor := StartSectorMajor;

    (*  ctMAPDRV. *)
    regs.C  := ctMAPDRV;

    (* Address of a 8 byte buffer with mapping data. *)
    regs.HL := Addr(Params);
    
    MSXBDOS ( regs );
end;

function GetZ80AccessMode (DriverSlot: byte): byte;
begin
    FillChar( regs, SizeOf( regs ), 0 );
    
    (*ctZ80MODE. *)
    regs.C := ctZ80MODE;
    
    (* Driver slot number. *)
    regs.A := DriverSlot;
    
    (* get current Z80 access mode *)
    regs.B := 0;

    MSXBDOS ( regs );
    
    GetZ80AccessMode := regs.D;
end;

function SetZ80AccessMode ( DriverSlot: byte; AccessMode: boolean ): byte;
begin
    FillChar( regs, SizeOf( regs ), 0 );
    
    (*ctZ80MODE. *)
    regs.C := ctZ80MODE;
    
    (* Driver slot number. *)
    regs.A := DriverSlot;
    
    (* set current Z80 access mode *)
    regs.B := 1;
    
    if AccessMode then
        regs.D := $FF  (* Enable.  *)
    else
        regs.D := $00; (* Disable. *)

    MSXBDOS ( regs );
    
    SetZ80AccessMode := regs.D;
end;
