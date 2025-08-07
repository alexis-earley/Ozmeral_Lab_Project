

z = load((fullfile(ProtocolPath,sFiles([1]).FileName)));
thing = z.F.events([28]).times;
isempty(thing)
%TotalTime = z.Time(1,2)-z.Time(1,1); 

