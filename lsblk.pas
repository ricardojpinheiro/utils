{
   lsblk.pas
   
   Copyright 2024 Ricardo Jurczyk Pinheiro <ricardojpinheiro@gmail.com>
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02110-1301, USA.
}

program lsblk;

{$i d:types.pas}
{$i d:msxdos.pas}
{$i d:msxdos2.pas}
{$i d:nextor.pas}

const
    maxpartitions   = 8;
    maxdevices      = 8;
    maxdriveletters = 8;

type
    TDeviceType = (Drive, Device, Floppy, RAMDisk);
    TPartitionType = (primary, extended, logical);
    
    Partition = record
        PartitionNumber: byte;
        PartitionType: TPartitionType;  
        DriveAssignedToPartition: char;
        PartitionSize: real;
        PartitionSectors: real;
    end;

    DevicesOnMSX = record
        DeviceNumber, DriverSlot, DriverSegment, LUN: byte;
        Case DeviceType: TDeviceType of
            Device: (ExtendedPartitionNumber: byte;
                Partitions: array [1..maxpartitions] of Partition);
            Drive, Floppy, RAMDisk: (DriveAssigned: char);
    end;
var 
    Parameters:         TTinyString;
    DeviceDriver:       TDeviceDriver;
    DriveLetter:        TDriveLetter;
    DevicePartition:    TDevicePartition;
    PartitionResult:    TPartitionResult;
    Devices:            array [1..maxdevices] of DevicesOnMSX;
    c:                  Char;
    i, j, k:            byte;
    found:              boolean;
    HowManyDevices:     byte;

procedure CommandLine (KindOf: byte);
(*
*  1 - Version
*  2 - Help
*)

begin
    case KindOf of
        1: begin (* Version *)
                writeln(' _     _     _ _       ');
                writeln('| |___| |__ | | | __   ');
                writeln('| / __| ''_ \| | |/ /  ');
                writeln('| \__ \ |_) | |   <    ');
                writeln('|_|___/_.__/|_|_|\_\   ');             
                writeln;
                Writeln('Version 0.1 - Copyright (c) 2024 by');
                Writeln('Brazilian MSX Crew. Some rights');
                Writeln('reserved (not many!).');
                writeln;
                Writeln('This is a utility which can show the');
                Writeln('block devices, clearly inspired by');
                Writeln('the lsblk utility, from Linux.');
                writeln;
                Writeln('It''s licensed under the GPLv3+ license.');
                writeln('Yep, free software. You are free to');
                Writeln('change and redistribute it. But don''t');
                writeln('ask me about any warranties... Use it ');
                writeln('at your own risk. ');
                Writeln('http://gnu.org/licenses/gpl.html');
                writeln;
            end;
        2: begin (* Help *)
                Writeln('Usage: lsblk <parameters>');
                Writeln('Shows info about block devices on MSX.');
                writeln;
                Writeln('Parameters: ');
                writeln('None: Shows the current block devices.');
                Writeln('/b - Print the sizes in bytes.');
                Writeln('/d <part> - Show info about a specific');
                writeln('partition.');
                Writeln('/f - Shows the used filesystems too.');
                writeln('/l - Shows block devices as a list.');
                Writeln('/h - Show this help text and exit.');
                Writeln('/v - Show version info and exit.');
                writeln;
            end;
        end;
    halt;
end;

function DOSVEREnhancedDetection: byte;
begin
    FillChar (regs, SizeOf ( regs ), 0 );
    regs.C := ctGetMSXDOSVersionNumber;
    regs.B  := $005A;
    regs.HL := $1234;
    regs.DE := $ABCD;
    regs.IX := $0000;

    MSXBDOS ( regs );
    
    writeln;
    if regs.B < 2 then
        DOSVEREnhancedDetection := 0
    else
        if regs.IX = 0 then
            DOSVEREnhancedDetection := 1
        else
            DOSVEREnhancedDetection := 2;
end;

procedure GatherInfoAboutEverything;
var
    PrimaryOrExtended, ErrorCode: byte;
    aux1, aux2, temp1, temp2: real;
    HowManyDevices, HowManyPartitions: byte;

	procedure GatherInfoAboutDevices (HowManyDevices: byte);
	begin
		DeviceDriver.DriverIndex := HowManyDevices;
        GetInfoDeviceDriver (DeviceDriver);
        ErrorCode := regs.A;

        Devices[HowManyDevices].DeviceNumber := HowManyDevices;
        
        if DeviceDriver.DeviceOrDrive = 0 then
            Devices[HowManyDevices].DeviceType := Drive     (* Drive-based driver.  *)
        else
            Devices[HowManyDevices].DeviceType := Device;   (* Device-based driver. *)

        with Devices[HowManyDevices] do
        begin
            DriverSlot      := DeviceDriver.DriverSlot;
            DriverSegment   := DeviceDriver.DriverSegment;
            LUN             := 1;
        end;
	end;

	procedure GatherInfoAboutPartitionsAndDriveLetters (HowManyDevices, HowManyPartitions: byte;
														var ErrorCode: byte);
	var
		HowManyDriveLetters, LogicalPartitions: byte;
	
	begin
		if PrimaryOrExtended = 0 then
		begin
			DevicePartition.PrimaryPartition    := HowManyPartitions;
			DevicePartition.ExtendedPartition   := 0;
		end
		else
		begin
			DevicePartition.PrimaryPartition    := PrimaryOrExtended;
			DevicePartition.ExtendedPartition   := LogicalPartitions;
			LogicalPartitions := LogicalPartitions + 1;
		end;
		
		GetInfoDevicePartition (DevicePartition, PartitionResult);
		
		ErrorCode     := regs.A;
		
		Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionNumber := HowManyPartitions;
		
		if ErrorCode <> ctIPART then
			case PartitionResult.PartitionType of
				1,4,6,14:   begin
								if PrimaryOrExtended = 0 then
									Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionType      := primary
								else
									Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionType      := logical;
								
								temp1 := PartitionResult.PartitionSizeMajor;
								temp2 := PartitionResult.PartitionSizeMinor;
								
{------------------------------------------------------------------------------}
{
writeln('PartitionSize: ', temp1:0:0, ' ', temp2:0:0);
}
{------------------------------------------------------------------------------}        
								
								FixBytes (temp1, temp2);
								
								Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionSize	:= SizeBytes(temp1, temp2);

								temp1 := PartitionResult.StartSectorMajor;
								temp2 := PartitionResult.StartSectorMinor;

{------------------------------------------------------------------------------}
{
writeln('StartSector: ', temp1:0:0, ' ', temp2:0:0);
}
{------------------------------------------------------------------------------}        

								FixBytes (temp1, temp2);
								
								Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionSectors	:= SizeBytes(temp1, temp2);
								
								aux1 := Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionSectors;
								aux2 := 0;

								HowManyDriveLetters := 1;
								
								while ( HowManyDriveLetters <= maxdriveletters ) and ( aux1 <> aux2 ) do
								begin
									DriveLetter.PhysicalDrive := chr(64 + HowManyDriveLetters);
									GetInfoDriveLetter (DriveLetter);
									aux2 := DriveLetter.FirstDeviceSectorNumber;
									if Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionSectors = DriveLetter.FirstDeviceSectorNumber then
										Devices[HowManyDevices].Partitions[HowManyPartitions].DriveAssignedToPartition := DriveLetter.PhysicalDrive;
									HowManyDriveLetters := HowManyDriveLetters + 1;
								end;
							end;
				5: begin
						Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionType     := extended;
						PrimaryOrExtended 														:= HowManyPartitions;
						LogicalPartitions														:= 1;
{
						Devices[HowManyDevices].ExtendedPartitionNumber          := DevicePartition.PrimaryPartition;
						Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionNumber    := j;
}
					end;
			end;

{------------------------------------------------------------------------------}
{
		writeln('Device ', HowManyDevices, ' Partition ', HowManyPartitions);
		writeln('ErrorCodeInvalidPartitionNumber: ', ErrorCode);
		writeln('PrimaryOrExtended: ', PrimaryOrExtended);
}
{------------------------------------------------------------------------------}

	end;

	procedure GatherInfoAboutPartitionsOnDevice (HowManyDevices: byte);
	begin
		PrimaryOrExtended := 0;
		
(*  Some information which is common for each device.                       *)
        
		DevicePartition.DriverSlot      := Devices[HowManyDevices].DriverSlot;
		DevicePartition.DriverSegment   := Devices[HowManyDevices].DriverSegment;
		DevicePartition.DeviceIndex     := HowManyDevices;
		DevicePartition.LUN             := Devices[HowManyDevices].LUN;
		DevicePartition.GetInfo         := true;

(*  If the device has a driver, then it would have partitions. Here goes an 
    effort to map primary, extended and logical partitions, and associates a
    drive letter to them. Obviously, the extended partition doesn't have any
    drive letters associated. 			                                     *)
            
		HowManyPartitions := 1;
		ErrorCode := 0;
				
		while 	( HowManyPartitions <= maxpartitions ) and ( ErrorCode <> ctIPART ) do
		begin
			GatherInfoAboutPartitionsAndDriveLetters (HowManyDevices, HowManyPartitions, ErrorCode);

{-----------------------------------------------------------------------------}

writeln('Device ', HowManyDevices, ' partition ', HowManyPartitions, '  ');
case Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionType of
	primary:    writeln('It''s a primary partition. ');
	extended:   writeln('It''s a extended partition.');
	logical:   	writeln('It''s a logical partition.');
end;
writeln ('Drive letter: ', Devices[HowManyDevices].Partitions[HowManyPartitions].DriveAssignedToPartition);
writeln ('Partition size: ', Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionSize:2:0);
writeln ('Initial sector: ', Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionSectors:2:0);
writeln;    

{-----------------------------------------------------------------------------} 			
			
			HowManyPartitions := HowManyPartitions + 1;
		end;
	end;

begin
    FillChar(Devices, SizeOf ( Devices ), 0 );
    FillChar(Regs, SizeOf ( Regs ), 0 );

(*  Find how many devices are used in the MSX and get info about them. *)

    i := 1;
    ErrorCode := 0;

    while ErrorCode <> ctIDRVR do
    begin
		GatherInfoAboutDevices (i);
{-----------------------------------------------------------------------------}
{
case Devices[i].DeviceType of
    Drive:      writeln (' Device ', i , ' has a drive-based driver.   ');
    Device:     writeln (' Device ', i , ' has a device-based driver.  ');
end;
}
{-----------------------------------------------------------------------------}

        i := i + 1;
    end;
	
	HowManyDevices := i;

	HowManyPartitions := 0;

    i := 1;
    
    while i <= HowManyDevices do
    begin
        if Devices[i].DeviceType = Device then
			GatherInfoAboutPartitionsOnDevice (i);

		i := i + 1;
	end;
end;

procedure PrintInfoAboutPartitions;
begin
    HowManyDevices := HowManyDevices - 1;
    
    writeln;
    writeln('There are ', HowManyDevices, ' devices on your MSX.');
    
    for i := 1 to HowManyDevices do
    begin
        write('Device ',    i, ' Slot ', Devices[i].DriverSlot, ' Segment ', 
                        Devices[i].DriverSegment, ' LUN ', Devices[i].LUN, ' ');
        
        case Devices[i].DeviceType of
            Drive:      begin
                            write(' Drive-based driver. ');
                            writeln(' Drive letter: ', Devices[i].DriveAssigned);
                        end;
                        
            Device:     begin
                            j := 1;
                            write(' Device-based driver. ');
							write('Device ', i, ' partition ', Devices[i].Partitions[j].PartitionNumber);
							case Devices[i].Partitions[j].PartitionType of
								primary: 	writeln(' Partition ', Devices[i].Partitions[j].PartitionNumber, ' is a primary partition.');
								extended: 	writeln(' Partition ', Devices[i].Partitions[j].PartitionNumber, ' is a extended partition.');
								logical: 	writeln(' Partition ', Devices[i].Partitions[j].PartitionNumber, ' is a logical partition.');
							end;

							if ord(Devices[i].Partitions[j].DriveAssignedToPartition) <> 0 then
								writeln(' Drive letter: ', Devices[i].Partitions[j].DriveAssignedToPartition);

							writeln (' Partition size: ', Devices[i].Partitions[j].PartitionSize:0:0, ' sectors, or ', 
															((Devices[i].Partitions[j].PartitionSize)/2048):0:0, ' Mb.');
							writeln (' Initial sector: ', Devices[i].Partitions[j].PartitionSectors:0:0);
							writeln;
							j := j + 1;
{
                            while ( j <= maxpartitions ) or ( Devices[i].Partitions[j].PartitionNumber <> 0 ) do
                            begin
                                writeln(' Partition ', Devices[i].Partitions[j].PartitionNumber);
                                case Devices[i].Partitions[j].PartitionType of
                                    primary : writeln(' It''s a primary partition.');
                                    extended: writeln(' It''s a extended partition.');
                                    logical : writeln(' It''s a logical partition.');
                                end;
                                writeln(' Drive letter: ', Devices[i].Partitions[j].DriveAssignedToPartition);
                                writeln(' Partition size: ', Devices[i].Partitions[j].PartitionSize:0:0, ' bytes.');
                                writeln(' First sector of partition: ', Devices[i].Partitions[j].PartitionSectors:0:0);
                                j := j + 1;
                            end;
}
                        end;
            Floppy:     write(' Floppy drive. ');
            RAMDisk:    begin
                            write(' RAM Disk. ');
                            writeln;
                            writeln(' Drive letter: ', Devices[i].DriveAssigned);
                        end;
        end;
        writeln;
    end;
end;

BEGIN
(*  Detects if it's MSX-DOS 1, MSX-DOS 2 or Nextor. *)

    case DOSVEREnhancedDetection of
        0:  begin
                writeln ('MSX-DOS 1 detected, so lsblk won''t run.');
                halt;
            end;
        1:  begin
                writeln ('MSX-DOS 2 detected, so lsblk won''t run.');
                halt;
            end;
    end;

    GatherInfoAboutEverything;

    if paramcount = 0 then
    (*  Shows current information about zero allocation mode. *)
{
        PrintInfoAboutPartitions
}
    else
    begin
        for i := 1 to paramcount do
        begin
            Parameters := paramstr(i);
                for j := 1 to length(Parameters) do
                    Parameters[j] := upcase(Parameters[j]);

                c := Parameters[2];
                if Parameters[1] = '/' then
                begin
                    delete(Parameters, 1, 2);
                (*  Parameters. *)
                    case c of
                        'V': CommandLine(1);        (* Help     *)
                        'H': CommandLine(2);        (* Version  *)
                        'B':    begin               (* Print the sizes in bytes. *)
                                end;
                                
                        'D':    begin               (* Show info about a specific partition. *)
                                end;
                                
                        'F':    begin               (* Shows the used filesystems too. *)
                                end;
                                
                        'L':    begin               (* Shows block devices as a list. *)
                                end;
                        
                    end;
                end;
        end;
    end;    
END.

