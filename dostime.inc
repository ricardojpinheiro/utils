(*<dostime.pas> CopyLeft (c) since 1995 by PopolonY2k. *)

(* Module constant definitions *)

Const     __ctError : Byte = $FF; { MSXDOS error code For internal use only }

Procedure DOSGetDate( Var date : TDate );
Var
       regs   : TRegs;
Begin
  regs.C := ctGetDate;

  MSXBDOS( regs );

  date.nYear  := regs.HL;
  date.nMonth := regs.D;
  date.nDay   := regs.E;
End;
