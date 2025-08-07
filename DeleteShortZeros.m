function [sFiles] = DeleteShortZeros(sFiles, ProtocolPath) 

    for i = 1:length(sFiles)

        CurrFile = sFiles([i]);

        FName = fullfile(ProtocolPath,CurrFile.FileName);
        z = load(FName,'F');
        
        FileEvents = z.F.events;
        j = 1;
        for j = 1:length(FileEvents)
            FileLabel = FileEvents(j).label;
            if FileLabel == '0'
                break;
            end
        end

        FileTimes = z.F.events(j).times;

        NewTimes = [FileTimes(1)];
        
        for k = 2:length(FileTimes)

            if FileTimes(k) - FileTimes(k-1) >= 0.01
                NewTimes(end + 1) = FileTimes(k);
            end
        end

        z.F.events(j).times = NewTimes;
        NewEpochs = ones(1,length(NewTimes));
        z.F.events(j).epochs = NewEpochs;

        F = z;

        save(FName,'F');

end