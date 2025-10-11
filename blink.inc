{Needs wrtvram.inc }

{Some blink routines by Kari Lammassaari
 This file contains following procedures:

  - _WrtVdp(Register,Value:Byte);
  - BlinkChar(Column,Row:Byte);
  - ClearBlinkChar(Column,Row:Byte);
  - Blink(Column,Row,BlinkLength:Byte);
  - ClearBlink(Column,Row,BlinkLength:Byte);
  - ClearAllBlinks;
  - SetBlinkRate(OnTime,OffTime:Byte); Time values 0 - 15
  - SetBlinkColors(ForeGroundColor,BackGroundColor:Byte);
  - Procedure CursorBlink(Len:Byte);
  - Procedure ClearCursorBlink(Len:Byte);
}

Const Vdp14     = 13; {Blink rate register in vdp}
      Vdp13     = 12; {Blink colors High nibble = foreground}

      SetB      = True;
      ResB      = False; {Switch values for setbit }

Var
    ColTbl: Array[0..255] Of Byte;
    TXTCOL: Integer Absolute $f3b5;  {Blink table addr}
    
Procedure WrtVdp (Port, Value: Byte);
Begin
    Inline ($F3/$3A/ Value  /$D3/$99/$3A/ Port /$F6/$80/$D3/$99 );
End;

Procedure SetBlinkRate (OnTime, OffTime: Byte);
Begin
    WrtVdp(Vdp14, OnTime * 16 + OffTime);
End;

Procedure SetBlinkColors (ForegroundColor, BackGroundColor: Byte);
Begin
    WrtVdp(Vdp13, ForegroundColor * 16 + BackgroundColor);
End;

Procedure SetBit (TableAddr, BitNumber: Byte; Operation: Boolean);
Const 
    MaskTable: Array[0..7] Of Byte = (128,64,32,16,8,4,2,1);
Var
    Byt :Byte;
begin
    Byt := ColTbl[TableAddr];
    If Operation = SetB Then  Byt := Byt Or MaskTable[BitNumber]
    Else Byt := Byt and (255-MaskTable[BitNumber]);
    ColTbl[TableAddr] := Byt;
End; {SetBit}

Procedure Blink (Col, Row, Len: Byte);
Var
    TableAddr :Integer;
    Bit,i     :Byte;
Begin
    TableAddr :=  ((row-1) * 80 + Col-1) Div 8;
    Bit       :=  ((Row-1) * 80 + Col-1) Mod 8;

    For i:= 1 to Len Do
    Begin
        SetBit(TableAddr, Bit, SetB);
        bit := Bit + 1;
        If Bit = 8 Then
        Begin
            bit := 0;
            TableAddr := TableAddr + 1;
        End;
    End;
    WriteVram(0, TXTCOL, Addr(ColTbl), 256);
End; {Blink}

Procedure ClearAllBlinks;
Begin
    FillChar (ColTbl, 256, 0);
    WriteVram(0, TXTCOL, Addr(ColTbl), 256);
End; {ClearAllBlinks}
