(*<msxdos.pas>
 * MSXDOS and CP/M structures definitions and functions.
 * Some data structures were converted from ASCII Corp. MSX-C Compiler and
 * others from books and specifications about MSX disk management.
 * CopyLeft (c) since 1995 by PopolonY2k.
 *)

(**
  *
  * $Id: msxdos.pas 98 2015-08-21 01:28:40Z popolony2k $
  * $Author: popolony2k $
  * $Date: 2015-08-21 01:28:40 +0000 (Fri, 21 Aug 2015) $
  * $Revision: 98 $
  * $HeadURL: file:///svn/p/oldskooltech/code/msx/trunk/msxdos/pascal/msxdos.pas $
  *)

(*
 * This module depends on folowing include files (respect the order):
 * - types.pas;
 *)

(* BDOS/MSXDOS functions list - Official function names *)

Const   ctReset                = $0;    { system reset                    }
        ctConIn                = $1;    { console input                   }
        ctConOut               = $2;    { console output                  }
        ctAuxIn                = $3;    { auxiliary input                 }
        ctAuxOut               = $4;    { auxiliary output                }
        ctLstOut               = $5;    { list output                     }
        ctDirCon               = $6;    { direct console I/O              }
        ctRawIn                = $7;    { direct console input            }
        ctDirIn                = $8;    { console input (no echo)         }
        ctStrOut               = $9;    { print string                    }
        ctGetLin               = $A;    { console line input              }
        ctConStat              = $B;    { console status                  }
        ctVerNo                = $C;    { get CP/M version number         }
        ctResDsk               = $D;    { reset disk system               }
        ctSetDrive             = $E;    { set default drive               }
        ctOpen                 = $F;    { open file                       }
        ctClose                = $10;   { close file                      }
        ctSearF                = $11;   { search for first                }
        ctSearN                = $12;   { search for next                 }
        ctDelete               = $13;   { delete file                     }
        ctCPMRead              = $14;   { read next record  (*)           }
        ctCPMWrite             = $15;   { write next record (*)           }
        ctCreate               = $16;   { create file                     }
        ctRename               = $17;   { rename file                     }
        ctLogVec               = $18;   { get login vector                }
        ctGetDrive             = $19;   { get default drive               }
        ctSetDMA               = $1A;   { set DMA address                 }
        ctGetAloc              = $1B;   { get allocation parameter        }
        ctReadRndm             = $21;   { random read   (*)               }
        ctWrtRndm              = $22;   { random write  (*)               }
        ctFileSize             = $23;   { get file size (*)               }
        ctSetRec               = $24;   { set random record (*)           }
        ctBlkWrite             = $26;   { random block write              }
        ctBlkRead              = $27;   { random block read               }
        ctWrtRndmZ             = $28;   { random write with zero fill (*) }
        ctGetDate              = $2A;   { get current date                }
        ctSetDate              = $2B;   { set current date                }
        ctGetTime              = $2C;   { get current time                }
        ctSetTime              = $2D;   { set current time                }
        ctSetVeri              = $2E;   { set/reset verify flag           }
        ctAbsRead              = $2F;   { absolute sector read            }
        ctAbsWrit              = $30;   { absolute sector write           }
        ctInitDMA              = $0080; { default DMA area                }


(**
  * Execute a MSX BDOS function.
  * @param regs The registers needed to call a specific DOS2 function;
  *)
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
