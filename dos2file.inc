(*<dos2file.pas> CopyLeft (c) since 1995 by PopolonY2k. *)

Const   ctInvalidFileHandle        = $FF; { Invalid file handle operation }
        ctInvalidOpenMode          = $FE; { Invalid file open mode }
        ctReadWriteError           = -1;  { Read/Write error operation }

        { @see FileSeek operation }
        ctSeekSet           : Byte = 0;   { Relative Beginning of the file }
        ctSeekCur           : Byte = 1;   { Relative current pointer position }
        ctSeekEnd           : Byte = 2;   { Relative end of file }

(* The file mode type for @see FileOpen function call; *)

Type TFileMode = String[3];

(**
  * Open/Create a file with specified file name;
  * @param strFileName The name of file to open/create;
  * @param strMode The mode for FileOpen function.
  * The possible values are:
  * o r  Read only mode;
  * o w  Write only mode;
  * o rw Read/Write mode;
  * o w+ Write only, creating the file if not exist;
  * o rw+ Read/Write mode, creating the file if not exist;
  * The function return the file handle for opened file or ctInvalidFileHandle
  * value;
  *)
Function FileOpen( Var strFileName : TFileName; strMode : TFileMode ) : Byte;
Var
        szFileName : Array[0..ctMaxPath] Of Char;
        regs       : TRegs;
        nRet,
        nOpenMode  : Byte;

  (**
    * Internal function to check if the file mode is valid;
    * @param strMode The mode to check;
    *)
  Function _IsValidMode( strMode : TFileMode ) : Boolean;
  Begin
    _IsValidMode := ( ( strMode = 'r' )  Or
                      ( strMode = 'w' )  Or
                      ( strMode = 'rw' ) Or
                      ( strMode = 'w+' ) Or
                      ( strMode = 'rw+' ) );
  End;

Begin      { Main function entry point }
  nRet := ctInvalidOpenMode;

  If( _IsValidMode( strMode ) )  Then
  Begin
    nRet := Length( strFileName );

    If( ( nRet > 0 ) And ( Length( strMode ) > 0 ) )  Then
    Begin
      Move( strFileName[1], szFileName, nRet );
      FillChar( regs, SizeOf( regs ), 0 );
      szFileName[nRet] := #0;
      nOpenMode := 0;

      { Check the open mode }
      If( strMode = 'r' )  Then
        nOpenMode := 1
      Else
        If( strMode[1] = 'w' )  Then
          nOpenMode := 2;

      nRet := Length( strMode );

      If( strMode[nRet] = '+' )  Then
        regs.C := ctCreateFileHandle
      Else
        regs.C := ctOpenFileHandle;

      regs.A  := nOpenMode;
      regs.DE := Addr( szFileName );
      MSXBDOS( regs );

      If( regs.A = 0 )  Then
        nRet := regs.B
      Else
        nRet := ctInvalidFileHandle;
    End
    Else
      nRet := ctInvalidFileHandle;
  End;

  FileOpen := nRet;
End;

(**
  * Close a file handle previously opened by the @see FileOpen function.
  * @param nFileHandle The file handle to close;
  * The function return False for error or True for success;
  *)
Function FileClose( nFileHandle : Byte ) : Boolean;
Var
        regs : TRegs;
        bRet : Boolean;

Begin
  regs.C := ctCloseFileHandle;
  regs.B := nFileHandle;
  MSXBDOS( regs );

  bRet := ( regs.A = 0 );

  FileClose := bRet;
End;

(**
  * Flush all data of file handle to disk;
  * @param nFileHandle The file handle to flush;
  * The function return False for error or True for success;
  *)
Function FileFlush( nFileHandle : Byte ) : Boolean;
Var
        regs : TRegs;
        bRet : Boolean;

Begin
  regs.C := ctEnsureFileHandle;
  regs.B := nFileHandle;
  MSXBDOS( regs );

  bRet := ( regs.A = 0 );

  FileFlush := bRet;
End;

(**
  * Duplicate a existing file handle.
  * @param nFileHandle The file handle to duplicate;
  * The function return the file handle for opened file or ctFileOpenError
  * value;
  *)
Function FileDuplicate( nFileHandle : Byte ) : Byte;
Var
        regs : TRegs;
        nRet : Byte;

Begin
  nRet   := ctInvalidFileHandle;
  regs.C := ctDuplicateFileHandle;
  regs.B := nFileHandle;
  MSXBDOS( regs );

  If( regs.A = 0 )  Then
    nRet := regs.B;

  FileDuplicate := nRet;
End;

(**
  * Move the current pointer of opened file handle, to a new position.
  * @param nFileHandle The file handle to perform the position change;
  * @param nOffset The new offset of the file handle pointer;
  * @param nOrigin The position from where nOffset is added. This
  * parameter is specified by one of following constants defined like
  * below:
  * ctSeekSet - Relative Beginning of the file;
  * ctSeekCur - Relative current pointer position;
  * ctSeekEnd - Relative end of file;
  * @param nNewPos The new file pointer position;
  *)
Function FileSeek( nFileHandle : Byte;
                   nOffset : Integer;
                   nOrigin : Byte;
                   Var nNewPos : Integer ) : Boolean;
Var
        regs    : TRegs;
        bRet    : Boolean;

Begin
  regs.C  := ctMoveFileHandlePointer;
  regs.A  := nOrigin;
  regs.B  := nFileHandle;
  regs.DE := 0;   { TODO: 32 bit seek operation ?????? }
  regs.HL := nOffset;
  MSXBDOS( regs );

  bRet := ( regs.A = 0 );

  If( bRet )  Then
  Begin
    nNewPos := regs.HL;
    { TODO: Addr DE here if has support for 32Bit seek operations }
  End;

  FileSeek := bRet;
End;

(**
  * Read a block of data from a file handle.
  * @param nFileHandle The file handle to perform a block read;
  * @param aBuffer The reference to the buffer to receive the block read;
  * @param nBytesToRead Number of bytes to read bythe function;
  * The function return the number of bytes really read;
  *)
Function FileBlockRead( nFileHandle : Byte;
                        Var aBuffer;
                        nBytesToRead : Integer ) : Integer;
Var
        regs : TRegs;
        nRet : Integer;

Begin
  nRet    := ctReadWriteError;
  regs.C  := ctReadFromFileHandle;
  regs.B  := nFileHandle;
  regs.DE := Addr( aBuffer );
  regs.HL := nBytesToRead;
  MSXBDOS( regs );

  If( regs.A = 0 )  Then
    nRet := regs.HL;

  FileBlockRead := nRet;
End;

(**
  * Write a block of data to a file handle.
  * @param nFileHandle The file handle to perform a block write;
  * @param aBuffer The reference to the buffer containing the block to write;
  * @param nBytesToWrite Number of bytes to write by the function;
  * The function return the number of bytes really written;
  *)
Function FileBlockWrite( nFileHandle : Byte;
                         Var aBuffer;
                         nBytesToWrite : Integer ) : Integer;
Var
        regs : TRegs;
        nRet : Integer;

Begin
  nRet    := ctReadWriteError;
  regs.C  := ctWriteToFileHandle;
  regs.B  := nFileHandle;
  regs.DE := Addr( aBuffer );
  regs.HL := nBytesToWrite;
  MSXBDOS( regs );

  If( regs.A = 0 )  Then
    nRet := regs.HL;

  FileBlockWrite := nRet;
End;
