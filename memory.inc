(**<memory.pas> CopyLeft (c) since 1995 by PopolonY2k. *)

(* Get the a integer value based on address passed by parameter. *)
Function GetInteger( Var nAddress : Integer ) : Integer;
Var
        nCount  : Byte;
        nResult : Integer;

Begin
  nCount := SizeOf( Integer );
  Move( Mem[nAddress], Mem[Addr( nResult )], nCount );
  nAddress := nAddress + nCount;
  GetInteger := nResult;
End;

(* Get the a byte memory position based on address passed *)
Function GetByte( Var nAddress : Integer ) : Byte;
Var
        nResult : Byte;

Begin
  nResult  := Mem[nAddress];
  nAddress := nAddress + 1;
  GetByte  := nResult;
End;
