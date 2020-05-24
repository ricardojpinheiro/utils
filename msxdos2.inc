(*<msxdos2.pas> CopyLeft (c) since 1995 by PopolonY2k. *)
Const
    ctOpenFileHandle                = $43;
	ctCreateFileHandle              = $44;
	ctCloseFileHandle               = $45;
	ctEnsureFileHandle              = $46;
    ctDuplicateFileHandle           = $47;
    ctReadFromFileHandle            = $48;
	ctWriteToFileHandle             = $49;
    ctMoveFileHandlePointer         = $4A;
	ctMoveFileHandle                = $54;
    ctGetPreviousErrorCode          = $65;
    ctExplainErrorCode              = $66;
    ctGetMSXDOSVersionNumber        = $6F;

(* The struct representing the MSXDOS version number. *)
Type TMSXDOSVersion = Record
  nKernelMajor,
  nKernelMinor,
  nSystemMajor,
  nSystemMinor    : Byte;
End;

(* Return the MSXDOS version. *)
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
