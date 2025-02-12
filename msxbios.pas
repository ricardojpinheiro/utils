(*<msxbios.pas>
 * MSX-BIOS management function library.
 * Copyright (c) since 1995 by PopolonY2k.
 *)

(**
  *
  * $Id: msxbios.pas 103 2020-06-17 00:40:53Z popolony2k $
  * $Author: popolony2k $
  * $Date: 2020-06-17 00:40:53 +0000 (Wed, 17 Jun 2020) $
  * $Revision: 103 $
  * $HeadURL: file:///svn/p/oldskooltech/code/msx/trunk/msxdos/pascal/msxbios.pas $
  *)

(*
 * This module depends on folowing include files (respect the order):
 * - types.pas;
 *)

(**
  * MSXBIOS struct and data definitions
  *)
Const     ctMaxSlots        = 4;    { Max. MSX slots           }
          ctMaxSecSlots     = 4;    { Max. MSX secondary slots }



(**
  * Return the Slot number for use in BIOS calls like
  * CALSLT, WRTSLT, RDSLT. Check MSX technical information
  * for details;
  * Slot calculation described below:
  *
  * FxxxSSPP
  * |   ||||
  * |   ||++--- Primary slot number (0-3)
  * |   ++----- Secondary slot number (0-3)
  * +---------- If secondary slot number specified
  * @param nPrimarySlot The primary slot number to compose the
  * @see TSlotNumber;
  * @param nSecondarySlot The secondary slot number to compose the
  * @see TSlotNumber;
  *)
Function MakeSlotNumber( nPrimarySlot, nSecondarySlot : Byte ) : TSlotNumber;
Begin
  MakeSlotNumber := ( nPrimarySlot + 128 ) Or ( nSecondarySlot ShL 2 );
End;

(**
  * Retrieve the slot number splited in Primary and secondary slot
  * for a given composite slot number;
  * @param nSlotNumber The composite slot number;
  * @param nPrimarySlot The primary slot number retrieved;
  * @param nSecondarySlot The secondary slot number retrieved;
  *)
Procedure SplitSlotNumber( nSlotNumber : TSlotNumber;
                           Var nPrimarySlot, nSecondarySlot : Byte );
Begin
  nPrimarySlot   := nSlotNumber And 3;
  nSecondarySlot := ( nSlotNumber And 12 ) ShR 2;
End;

(* MSXBIOS Routines to support slots management *)

(**
  * Write a byte to specified memory/slot position.
  * @param nSlotNumber The @see TSlotNumber containing the slot information;
  * @param nAddr Memory address;
  * @param nData Data to write;
  *)
Procedure WRSLT( nSlotNumber : TSlotNumber; nAddr : Integer; nData : Byte );
Begin
  InLine( $ED/$5B/nData/          { LD DE, (nData)      }
          $3A/nSlotNumber/        { LD A, (nSlotNumber) }
          $2A/nAddr/              { LD HL, (nAddr)      }
          $CD/$14/$00/            { CALL WRSLT          }
          $FB                     { EI                  }
        );
End;

(**
  * Retrieve a data from specified Slot/Address;
  * @param nSlotNumber The @see TSlotNumber containing the slot information;
  * @param nAddr Address to retrieve data;
  *)
Function RDSLT( nSlotNumber : TSlotNumber; nAddr : Integer ) : Byte;
Begin
  InLine( $3A/nSlotNumber/        { LD A, (nSlotNumber) }
          $2A/nAddr/              { LD HL,(nAddr)       }
          $CD/$0C/$00/            { CALL RDSLT          }
          $32/nSlotNumber/        { LD (nSlotNumber), A }
          $FB                     { EI                  }
        );

  RDSLT := nSlotNumber;
End;

(**
  * Switches to indicated slot at indicated page.
  * @param nSlotNumber The @see TSlotNumber containing the slot information;
  * @param nPage The Page to enable;
  *)
Procedure ENASLT( nSlotNumber : TSlotNumber; nPage : Byte );
Begin
  nPage := nPage ShL 6;
  InLine( $3A/nPage/              { LD A, (nPage)       }
          $67/                    { LD H, A             }
          $3A/nSlotNumber/        { LD A, (nSlotNumber) }
          $CD/$24/$00             { CALL ENASLT         } );
End;

(**
  * Perform an inter-slot call through CALSLT MSX-BIOS
  * call.
  * @param regs The register struct to pass and receive
  * data to/from call;
  *)
Procedure CALSLT( Var regs : TRegs );
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
  nIY := Swap( regs.IY );

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
          $CD/$1C/$00/          { CALL &H001C; CALL CALSLT           }
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
          $F1/                  { POP AF                             }
          $FB                   { EI                                 }
        );

  (* Update the caller register struct *)
  regs.A  := nA;
  regs.F  := nF;
  regs.BC := nBC;
  regs.DE := nDE;
  regs.HL := nHL;
  regs.IY := nIY;
  regs.IX := nIX;
End;
