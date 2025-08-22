function Step6ECombineActiveLR2(inputDir, outputDir)

    if nargin < 2
        error('Need input and output directories.');
    end
    
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    matInfo = dir(fullfile(inputDir, '*.mat'));
    if isempty(matInfo)
        error('No .mat files found in %s', inputDir);
    end

    % Loop through all files
    for f = 1:numel(matInfo)
        filePath = fullfile(inputDir, matInfo(f).name);
        S = load(filePath);  % load struct
        rootName = fieldnames(S);  % Ex: {'All_Subjects_6C'}
        allSubj  = S.(rootName{1});

        newStruct = struct();
        condNames = fieldnames(allSubj);

        for i = 1:numel(condNames)
            cond = condNames{i};

            if startsWith(cond, 'Passive')
                newStruct.(cond) = allSubj.(cond);
                continue
            end

            dst = cond(1:8);  % Ex: Attend30L/R → Attend30

            if ~isfield(newStruct, dst)
                newStruct.(dst) = struct();
            end

            srcTriggers = fieldnames(allSubj.(cond));
            for t = 1:numel(srcTriggers)
                trig = srcTriggers{t};
                srcDat = allSubj.(cond).(trig);

                if ~isfield(newStruct.(dst), trig)
                    newStruct.(dst).(trig) = srcDat;
                else
                    dstDat = newStruct.(dst).(trig);
                    w1 = dstDat.num_files;
                    w2 = srcDat.num_files;
                    sumW = w1 + w2;

                    expW1 = repmat(w1, 1, size(dstDat.epoch_avg, 2));
                    expW2 = repmat(w2, 1, size(srcDat.epoch_avg, 2));

                    mergedAvg = (dstDat.epoch_avg .* expW1 + ...
                                 srcDat.epoch_avg .* expW2) ./ repmat(sumW, 1, size(dstDat.epoch_avg, 2));

                    newStruct.(dst).(trig).epoch_avg = mergedAvg;
                    newStruct.(dst).(trig).num_files = sumW;
                end
            end
        end

        % Save output using updated struct name
        [~, baseName, ~] = fileparts(matInfo(f).name);
        structOutName = [rootName{1}(1:end-2), '6E'];  % Ex: All_Subjects_6C → All_Subjects_6E
        outPath = fullfile(outputDir, [structOutName, '.mat']);
        tempStruct = struct();  % Clear previous data
        tempStruct.(structOutName) = newStruct;
        save(outPath, '-struct', 'tempStruct', '-v7.3');
        disp(['Saved: ', outPath]);
    end
end