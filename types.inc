(*<types.pas> * CopyLeft (c) since 1995 by PopolonY2k. *)
Const ctMaxPath = 127;    { Maximum path size - MSXDOS2 }
Type
    TFileName   = String[ctMaxPath];       { File name path type }
    Pointer = ^Byte;                   { Pointer generic type }
    TString = String[255];

(* Z80 registers struct/union definition *)
Type TRegs = Record
  IX       : Integer;             { 16Bit index registers }
  IY       : Integer;

  Case Byte Of    { 8Bit registers and 16Bit registers - WORD_REGS }
    0 : ( C,B,E,D,L,H,F,A  : Byte );      { 8bit registers  }
    1 : ( BC,DE,HL,AF      : Integer );   { 16bit registers }
End;
