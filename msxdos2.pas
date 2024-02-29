(*<msxdos2.pas>
 * MSXDOS2 function call structures definitions and functions.
 * CopyLeft (c) since 1995 by PopolonY2k.
 *)

(**
  *
  * $Id: msxdos2.pas 98 2015-08-21 01:28:40Z popolony2k $
  * $Author: popolony2k $
  * $Date: 2015-08-21 01:28:40 +0000 (Fri, 21 Aug 2015) $
  * $Revision: 98 $
  * $HeadURL: file:///svn/p/oldskooltech/code/msx/trunk/msxdos/pascal/msxdos2.pas $
  *)

(*
 * This module depends on folowing include files (respect the order):
 * - types.pas;
 * - msxdos.pas;
 *)

(*
 * MSXDOS2 function call list - Official function names.
 * Thanks to MSX Assembly pages at:
 * http://map.grauw.nl/resources/dos2_functioncalls.php
 *)

Const     ctFindFirstEntry                = $40;
          ctFindNextEntry                 = $41;
          ctFindNewEntry                  = $42;
          ctOpenFileHandle                = $43;
          ctCreateFileHandle              = $44;
          ctCloseFileHandle               = $45;
          ctEnsureFileHandle              = $46;
          ctDuplicateFileHandle           = $47;
          ctReadFromFileHandle            = $48;
          ctWriteToFileHandle             = $49;
          ctMoveFileHandlePointer         = $4A;
          ctIOCTL                         = $4B;
          ctTestFileHandle                = $4C;
          ctDeleteFileOrDirectory         = $4D;
          ctRenameFileOrDirectory         = $4E;
          ctMoveFileOrDirectory           = $4F;
          ctGetSetFileAttr                = $50;
          ctGetSetFileDateAndTime         = $51;
          ctDeleteFileHandle              = $52;
          ctRenameFileHandle              = $53;
          ctMoveFileHandle                = $54;
          ctGetSetFileHandleAttr          = $55;
          ctGetSetFileHandleAndDateTime   = $56;
          ctGetDiskTransferAddress        = $57;
          ctGetVerifyFlagSetting          = $58;
          ctGetCurrentDir                 = $59;
          ctChangeCurrentDir              = $5A;
          ctParsePathName                 = $5B;
          ctParseFileName                 = $5C;
          ctCheckCharacter                = $5D;
          ctGetWholePathString            = $5E;
          ctFlushDiskBuffers              = $5F;
          ctForkToChildProcess            = $60;
          ctRejoinParentProcess           = $61;
          ctTerminateWithErrorCode        = $62;
          ctDefineAbortExitRoutine        = $63;
          ctDefineDiskErrorHandlerRoutine = $64;
          ctGetPreviousErrorCode          = $65;
          ctExplainErrorCode              = $66;
          ctFormatDisk                    = $67;
          ctCreateOrDestroyRAMDisk        = $68;
          ctAllocateSectorBuffers         = $69;
          ctLogicalDriveAssignment        = $6A;
          ctGetEnvironmentItem            = $6B;
          ctSetEnvironmentItem            = $6C;
          ctFindEnvironmentItem           = $6D;
          ctGetSetDiskCheckStatus         = $6E;
          ctGetMSXDOSVersionNumber        = $6F;
          ctGetSetRedirectionState        = $70;


(**
  * The struct representing the MSXDOS version number.
  *)
Type TMSXDOSVersion = Record
  nKernelMajor,
  nKernelMinor,
  nSystemMajor,
  nSystemMinor    : Byte;
End;


(**
  * Return the MSXDOS version.
  * @param version The @see TMSXDOSVersion reference to
  * the struct to receive the MSXDOSVersion;
  *)
Procedure GetMSXDOSVersion( Var version : TMSXDOSVersion );
Var
       regs  : TRegs;
Begin
  FillChar( regs, SizeOf( regs ), 0 );
  regs.C:= ctGetMSXDOSVersionNumber;
  MSXBDOS( regs );

  If( regs.A = 0 )  Then
    With version Do
    Begin
      nKernelMajor := regs.B;
      nKernelMinor := regs.C;
      nSystemMajor := regs.D;
      nSystemMinor := regs.E;
    End;
End;
