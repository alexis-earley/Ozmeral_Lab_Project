function sFiles = DeleteShortTimes(sFiles, ProtocolPath) 

    sFilesNew = [];

    for i = 1:length(sFiles)

        z = load((fullfile(ProtocolPath,sFiles([i]).FileName)),'Time');
        TotalTime = z.Time(1,2)-z.Time(1,1); 
        if TotalTime < 0.01
            bst_process('CallProcess', 'process_delete', sFiles([i]), [], ...
            'target', 2);  % Delete folder
        else
            sFilesNew = [sFilesNew, sFiles([i])];
        end
    end 
    
    sFiles = sFilesNew;
   
end