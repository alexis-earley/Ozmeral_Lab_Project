function sFiles = DeleteShortTimes(sFiles, protocolPath, minTime) 

% Deletes files in brainstorm (sFiles) shorter than minTime.
% Ensure that protocolPath reflects where the protocol where the sFiles
% are located.

    sFilesNew = [];

    for i = 1:length(sFiles)

        z = load((fullfile(protocolPath,sFiles([i]).FileName)),'Time');
        TotalTime = z.Time(1,2)-z.Time(1,1); 
        if TotalTime < minTime
            bst_process('CallProcess', 'process_delete', sFiles([i]), [], ...
            'target', 2);  % Delete folder
        else
            sFilesNew = [sFilesNew, sFiles([i])];
        end
    end 
    
    sFiles = sFilesNew;
   
end
