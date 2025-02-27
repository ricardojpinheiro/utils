(*
*  zeroalo1.inc - Pascal library which is used with the zeroaloc utility;
*  Here we have some routines which are accessory to the program.
*)

const
    ctRALLOC                        =   $75; (* RALLOC routine.               *)
    ctGetMSXDOSVersionNumber        =   $6F;
    
    ctGetRallocStatus               =   $00;
    ctSetRallocStatus               =   $01;

type
    TBinNumber      = array [0..7] of byte;
    TDriveStatus    = TBinNumber;
    TTinyString     = String[40];              { String 40 byte size }
    
    TMSXDOSVersion  = Record
        nKernelMajor,
        nKernelMinor,
        nSystemMajor,
        nSystemMinor    : Byte;
    End;    

    TRegs           = Record
        IX       : Integer;             { 16Bit index registers }
        IY       : Integer;

        Case Byte Of    { 8Bit registers and 16Bit registers - WORD_REGS }
            0 : ( C,B,E,D,L,H,F,A  : Byte );      { 8bit registers  }
            1 : ( BC,DE,HL,AF      : Integer );   { 16bit registers }
    End;

var
    Regs:   TRegs;

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

Procedure MSXBDOS( Var regs : TRegs );
Var
        nA, nF         : Byte;
        nHL, nDE, nBC  : Integer;
        nIX, nIY       : Integer;
Begin
  nA  := regs.A;
  nHL := regs.HL;
  nDE := regs.DE;
  nBC := regs.BC;
  nIX := regs.IX;
  nIY := regs.IY;

  InLine( $F5/                  { PUSH AF      ; Push all registers  }
          $C5/                  { PUSH BC                            }
          $D5/                  { PUSH DE                            }
          $E5/                  { PUSH HL                            }
          $DD/$E5/              { PUSH IX                            }
          $FD/$E5/              { PUSH IY                            }
          $3A/nA/               { LD A , (nA )                       }
          $ED/$4B/nBC/          { LD BC, (nBC)                       }
          $ED/$5B/nDE/          { LD DE, (nDE)                       }
          $2A/nHL/              { LD HL, (nHL)                       }
          $DD/$2A/nIX/          { LD IX, (nIX)                       }
          $FD/$2A/nIY/          { LD IY, (nIY)                       }
          $CD/$05/$00/          { CALL 0005H - BDOS call             }
          $32/nA/               { LD (nA ), A                        }
          $ED/$43/nBC/          { LD (nBC), BC                       }
          $ED/$53/nDE/          { LD (nDE), DE                       }
          $22/nHL/              { LD (nHL), HL                       }
          $DD/$22/nIX/          { LD (nIX), IX                       }
          $FD/$22/nIY/          { LD (nIY), IY                       }
          $F5/                  { PUSH AF                            }
          $E1/                  { POP HL                             }
          $22/nF/               { LD (nF), HL                        }
          $FD/$E1/              { POP YI       ; Pop all registers   }
          $DD/$E1/              { POP IX                             }
          $E1/                  { POP HL                             }
          $D1/                  { POP DE                             }
          $C1/                  { POP BC                             }
          $F1                   { POP AF                             }
        );

  (* Update caller register struct *)
  regs.A  := nA;
  regs.F  := nF;
  regs.BC := nBC;
  regs.DE := nDE;
  regs.HL := nHL;
  regs.IY := nIY;
  regs.IX := nIX;
End;

Procedure GetMSXDOSVersion( Var version : TMSXDOSVersion );
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
    
