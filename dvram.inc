(**<dvram.pas>
  * Direct VRAM access functions to optimize screen
  * I/O operations.
  * Copyright (c) since 1995 by PopolonY2k.
  *)

(**
  *
  * $Id: dvram.pas 102 2016-06-22 12:26:54Z popolony2k $
  * $Author: popolony2k $
  * $Date: 2016-06-22 12:26:54 +0000 (Wed, 22 Jun 2016) $
  * $Revision: 102 $
  * $HeadURL: file:///svn/p/oldskooltech/code/msx/trunk/msxdos/pascal/dvram.pas $
  *)

(*
 * This module depends on folowing include files (respect the order):
 * - types.pas;
 *)

(**
  * Handle to direct output operations.
  * Used by @see OpenDirectTextMode() and @see CloseDirectTextMode();
  *)
Type TOutputHandle = Record
  nConOutPtr : Integer;
End;


(**
  * Read data from VRAM using direct access through
  * VDP I/O ports.
  * @param nX The position based on X-AXIS of screen;
  * @param nY The position based on Y-AXIS of screen;
  * The function return the data read;
  *)
Function DirectRead( nX, nY : Integer ) : Byte;
Var
      nAddr    : Integer;
      nData    : Byte;
      LINL40   : Byte Absolute $F3AE; { Width for SCREEN 0 }

Begin
  nAddr := ( $000 + ( LINL40 * ( nY - 1 ) ) + ( nX - 1 ) );

  InLine( $F3 );                              { DI                 }
  Port[$99] := Lo( nAddr );
  Port[$99] := ( Hi( nAddr ) And $3F ) or $40;

  InLine( $DB/$98/                            { IN A,( 98h )       }
          $DB/$98/                            { IN A,( 98h )       }
          $32/nData                           { LD ( VRAMData ), A }
        );

  InLine( $FB );                              { EI                 }

  DirectRead := nData;
End;

(**
  * Write a character to VRAM using direct access through
  * VDP I/O ports.
  * @param chChar The character to write;
  *)
Procedure DirectWrite( chChar : Char );
Var
       nAddr    : Integer;
       LINL40   : Byte Absolute $F3AE; { Width for SCREEN 0 }
       CRTCNT   : Byte Absolute $F3B1; { Number of lines on screen }
       CSRY     : Byte Absolute $F3DC; { Current row-position of the cursor }
       CSRX     : Byte Absolute $F3DD; { Current col-position of the cursor }

Begin
  If( Not ( chChar In[ #10, #13] ) )  Then     { Isn't CR/LF ?? }
  Begin
    nAddr := ( ( LINL40 * ( CSRY - 1 ) ) + ( CSRX - 1 ) );

    InLine( $F3 );                              { DI }
    Port[$99] := Lo( nAddr );
    Port[$99] := ( Hi( nAddr ) And $3F ) Or $40;
    Port[$98] := Byte( chChar );
    InLine( $FB );                              { EI }

    { Increase the cursor position }
    If( ( CSRX + 1 ) >= ( LINL40 - 1 ) )  Then
      CSRX := LINL40
    Else
      CSRX := CSRX + 1;
  End
  Else
    If( ( chChar = #10 ) And ( CSRY < CRTCNT ) ) Then  { Line feed ?? }
    Begin
      CSRY := CSRY + 1;
      CSRX := 1;
    End;
End;

(**
  * Open the video to use direct output function
  * @see DirectWrite.
  * @param handle Reference to the struct @see TOutputHandle
  * needed to initialize the direct output text mode;
  *)
Procedure OpenDirectTextMode( Var handle : TOutputHandle );
Begin
  handle.nConOutPtr := ConOutPtr;
  ConOutPtr := Addr( DirectWrite );
End;

(**
  * Close the direct access video mode, previously opened by
  * @see OpenDirectTextMode(), restoring the old text mode access;
  * @param handle The Reference to struct @see TOutputHandle
  * used to open the direct access mode;
  *)
Procedure CloseDirectTextMode( Var handle : TOutputHandle );
Begin
  ConOutPtr := handle.nConOutPtr;
  FillChar( handle, SizeOf( handle ), -1 );
End;
