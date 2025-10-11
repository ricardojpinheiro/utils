(*<dpb.pas> CopyLeft (c) since 1995 by PopolonY2k. *)

(* Internal MSXDOS & CP/M80 definitions *)

Const   ctMaxDskDevices : Byte = $8;    { Maximum disk drives devices }

(* Return codes *)

Const   ctOK            : Byte = $0;    { Success }
        ctError         : Byte = $1;    { Error }
        ctBDOSErr       : Byte = $FF;   { BDOS error value }

(* Disk formats *)

Const   ctSingleSided31_2 : Byte = $F8; { 31/2 Single Sided floppy }
        ctDoubleSided31_2 : Byte = $F9; { 31/2 Double Sided floppy }
        ctSingleSided51_4 : Byte = $FC; { 51/4 Single Sided floppy }
        ctDoubleSided51_4 : Byte = $FD; { 51/4 Double Sided floppy }

(* Disk side *)

Const   ctSingleSided     : Byte = $0;  { Single Sided }
        ctDoubleSided     : Byte = $1;  { Double Sided }

(* MSXDOS addresses *)

Const   ctMaxPhysicalDrv  = $F1C8;      { Maximum Physical drives }
        ctDefaultDrive    = $F247;      { Default drive }
        ctMSXDOSBoot      = $F346;      { Boot with or without MSXDOS }
        ctMaxLogicalDrv   = $F347;      { Maximum logical drives }
        ctDiskIntfSlot    = $F348;      { Disk interface slot }
        ctRAMFATAddress   = $F34D;      { Copy of FAT in RAM address }
        ctDMAAddress      = $F34F;      { DMA Address }
        ctSectorAddress   = $F351;      { Sector buffer address }
        ctFCBAddress      = $F353;      { FCB address }
        ctDPBAddress      = $F355;      { DPB start address SizeOf(int) step }
                                        { for each system drive ($F355 - A) }
                                        { ($F357 - B ...) }

(* File control block (FCB) data structure *)
Type  TFCB = Record
  DriveCode   : Char;                   { Drive code A, B, ... }
  Name        : Array [1..8] Of Char;   { File Name }
  Ext         : Array [1..3] Of Char;   { File Name Extention }
  _filler1_   : Array [1..2] Of Char;
  RecSize     : Integer;                { Record Size Used by Block I/O }
  FileSize    : Array[1..2] Of Integer; { File Size in Bytes }
  FCBDate     : Integer;
  FCBTime     : Integer;
  _filler2_   : Array [1..9] Of Char;
  RecPos      : Array[1..2] Of Integer; { Current Record Number }
  Mode        : Byte;                   { File Mode R, W, R/W }
End;

(* Disk Parameter Block (DPB) structure definition *)
Type TPDPB = ^TDPB;
TDPB = Record
  DrvNum               : Byte   ;       { Drive number ( A = 0, B = 1,... }
  DiskFormat           : Byte   ;       { Disk Format F8/F9/FA/FB/FC/FD/FE/FF }
  BytesPerSector       : Integer;       { Bytes per sector }
  Reserved             : Integer;       { Reserved (0Fh)- No information }
  DiskSides            : Byte   ;       { Number of disk sides }
  SectorsByCluster     : Byte   ;       { Sectors by cluster }
  ReservedSectors      : Integer;       { Number of reserved sectors }
  FATCount             : Byte   ;       { Number of FAT's }
  DirectoryEntries     : Byte   ;       { Directory entries }
  StorageEntrySector   : Integer;       { Initial disk sector - After FAT }
  DiskClusters         : Integer;       { Disk clusters }
  SectorsByFAT         : Byte   ;       { Sectors by FAT }
  DirectoryEntrySector : Integer;       { Start of Directory entry (Sector) }
  FatAreaMemoryAddress : Integer;       { FAT Memory Address (RAM) }
End;

(* Get the disk parameter block (DPB) for specified drive. *)
Function GetDPB( Drive : Byte; Var DPB : TDPB ) : Byte;
Var
      DPBRAMAddr : Integer;
      DPBAddr    : Integer;
      ErrorFlag  : Byte   ;
      TempFCB    : TFCB   ;

Begin
  ErrorFlag := ctOK;

  If( Drive > ctMaxDskDevices )  Then
    ErrorFlag  := ctError               { Error - Max drives limit reached }
  Else
  Begin
    { Just perform a disk operation to update the MSX's memory DPB.      }
    { Do this always because the user can change de disk from drive and  }
    { then the DPB  will be outdated.                                    }

    FillChar( TempFCB.Name, SizeOf( TempFCB.Name ), '?' );
    FillChar( TempFCB.Ext , SizeOf( TempFCB.Ext ) , '?' );
    TempFCB.DriveCode := Char( Drive + 65 );

    { DPB address }
    DPBRAMAddr := ( ctDPBAddress + ( 2 * Drive ) );
    DPBAddr    := GetInteger( DPBRAMAddr );
  End;

  { Return data }

  If( ErrorFlag = ctOK ) Then
  Begin
    DPB.DrvNum               := GetByte( DPBAddr );
    DPB.DiskFormat           := GetByte( DPBAddr );
    DPB.BytesPerSector       := GetInteger( DPBAddr );
    DPB.Reserved             := GetInteger( DPBAddr );
    DPB.DiskSides            := GetByte( DPBAddr );
    DPB.SectorsByCluster     := GetByte( DPBAddr );
    DPB.ReservedSectors      := GetInteger( DPBAddr );
    DPB.FATCount             := GetByte( DPBAddr );
    DPB.DirectoryEntries     := GetByte( DPBAddr );
    DPB.StorageEntrySector   := GetInteger( DPBAddr );
    DPB.DiskClusters         := GetInteger( DPBAddr );
    DPB.SectorsByFAT         := GetByte( DPBAddr );
    DPB.DirectoryEntrySector := GetInteger( DPBAddr );
    DPB.FatAreaMemoryAddress := GetInteger( DPBAddr );
  End;

  GetDPB := ErrorFlag;
End;
