
	function GatherInfoAboutPartitionsAndDriveLetters (HowManyDevices, 
										HowManyPartitions: byte): byte;
	var
		LogicalPartitions: byte;
	
	begin
		LogicalPartitions := 0;
		
		DevicePartition.PrimaryPartition    		:= HowManyPartitions;
		Devices[HowManyDevices].NumberOfPartitions 	:= HowManyPartitions;
		
		if PrimaryExtendedLogical = 0 then		(* It's a primary partition. *)
			DevicePartition.ExtendedPartition   := 0
		else
		if PrimaryExtendedLogical = 1 then
		begin								(* It's an extended partition. *)
			DevicePartition.ExtendedPartition   		:= LogicalPartitions;
			LogicalPartitions 							:= LogicalPartitions + 1;
		end;
		
		GetInfoDevicePartition (DevicePartition, PartitionResult);
		
		if ErrorCodeInvalidPartition <> ctIPART then
		begin
			GatherInfoAboutPartitionsAndDriveLetters    := regs.A;
			ErrorCodeInvalidPartition					:= regs.A;
		
			Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionNumber := HowManyPartitions;
			case PartitionResult.PartitionType of
				1,4,6,14:   begin
								if PrimaryExtendedLogical = 0 then
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
								
								while ( HowManyDriveLetters <= maxdriveletters ) AND ( aux1 <> aux2 ) do
								begin
									if Drives[HowManyDriveLetters] = false then		(* If this drive letter isn't found yet. *)
									begin
										DriveLetter.PhysicalDrive := chr(64 + HowManyDriveLetters);
										GetInfoDriveLetter (DriveLetter);
										aux2 := DriveLetter.FirstDeviceSectorNumber;
										if Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionSectors = DriveLetter.FirstDeviceSectorNumber then
										begin		(*	Compare based on first sector numbers. *)
											Devices[HowManyDevices].Partitions[HowManyPartitions].DriveAssignedToPartition := DriveLetter.PhysicalDrive;
											k := ord(DriveLetter.PhysicalDrive) - 64;
											Drives[k] := true;
										end;
									end;
									HowManyDriveLetters := HowManyDriveLetters + 1;
								end;
							end;
				5: begin
						Devices[HowManyDevices].Partitions[HowManyPartitions].PartitionType     := extended;
						PrimaryExtendedLogical 													:= 1;
						LogicalPartitions														:= 1;
					end;
			end;

{------------------------------------------------------------------------------}
{
		writeln('Device ', HowManyDevices, ' Partition ', HowManyPartitions);
		writeln('ErrorCodeInvalidPartitionNumber: ', ErrorCodeInvalidPartition);
		writeln('PrimaryExtendedLogical: ', PrimaryExtendedLogical);
}
{------------------------------------------------------------------------------}
		end;
	end;
		


	
