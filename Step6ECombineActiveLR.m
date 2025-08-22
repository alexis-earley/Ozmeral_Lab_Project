function Step6ECombineActiveLR(inputDir, outputDir)

    if nargin < 2
        error('Need input MAT file and output directory.');
    end
    
    if ~exist(outputDir,'dir'); mkdir(outputDir); end

    matInfo = dir(fullfile(inputDir,'*.mat')); % returns a 1‑element struct
    if isempty(matInfo)
        error('No .mat file found in %s', srcDir);
    elseif numel(matInfo) > 1
        error('More than one .mat file found in %s', srcDir);
    end
    
    filePath = fullfile(inputDir, matInfo(1).name);
    S = load(filePath); % struct containing the variables
    %load(inputDir);
    rootName = fieldnames(S); % e.g. {'All_Subjects_6D'}
    allSubj  = S.(rootName{1});

    newStruct = struct();
    condNames = fieldnames(allSubj);

    for i = 1:numel(condNames)
        cond = condNames{i};

        if startsWith(cond,'Passive') %copy passive
            newStruct.(cond) = allSubj.(cond);
            continue
        end

        % 2‑B  active: shorten to 'Attend30' or 'Attend60'
        dst = cond(1:8);  % first 8 chars

        if ~isfield(newStruct,dst)
            newStruct.(dst) = struct(); % initialise
        end

        srcTriggers = fieldnames(allSubj.(cond));
        for t = 1:numel(srcTriggers)
            trig = srcTriggers{t};
            srcDat = allSubj.(cond).(trig);

            if ~isfield(newStruct.(dst),trig)
                newStruct.(dst).(trig) = srcDat; % first time
            else
                dstDat = newStruct.(dst).(trig); % duplicate trigger

                w1 = dstDat.num_files; % 63×1
                w2 = srcDat.num_files;
                sumW = w1 + w2;

                % expand weights along time dimension for element‑wise math
                expW1 = repmat(w1,1,size(dstDat.epoch_avg,2));
                expW2 = repmat(w2,1,size(srcDat.epoch_avg,2));

                mergedAvg = (dstDat.epoch_avg .* expW1 + ...
                              srcDat.epoch_avg .* expW2) ./ repmat(sumW,1,1051);

                newStruct.(dst).(trig).epoch_avg = mergedAvg;
                newStruct.(dst).(trig).num_files  = sumW;
            end
        end
    end

    outName = 'All_Subjects_6E';
    outFile = fullfile(outputDir,[outName '.mat']);
    tmp.(outName) = newStruct;
    save(outFile,'-struct','tmp','-v7.3');
    disp(['Saved combined struct (weighted) to ', outFile]);
end
