function [sFiles,Orders] = FileType(sFiles, ProtocolPath) 

% Classifies each file in sFiles as either "Passive" or "Active"
% Presence of ‘60’ trigger -> active
% Otherwise -> passive

    Orders = [""];

    for i = 1:length(sFiles)

        CurrFile = sFiles([i]);

        z = load((fullfile(ProtocolPath,CurrFile.FileName)),'F');
        %FileEvents = z.F.events([28]).times;
        FileEvents = z.F.events;
        Index = 1;
        for Index = 1:length(FileEvents)
            FileLabel = FileEvents(Index).label;
            if FileLabel == '60'
                break;
            end
        end
        FileTimes = z.F.events(Index).times;
        Passive = isempty(FileTimes);
        
        Value = ceil(i / 4);
        Rem = mod(i, 4);
        if Rem == 0
            Rem = 4;
        end

        Value
        Rem

        if Passive
            Orders(Value,Rem) = "Passive";
            disp('Passive');
        else
            Orders(Value,Rem) = "Active";
            disp('Active');
        end
    end 

    Orders = Orders(2:end);
   
end
