function Step6D_Sep_Prequel(inputDir, outputDir, lowerThresh, upperThresh)

    if nargin < 4
        error('Usage: Step6CPeakToPeakClean(inputDir, outputDir, lowerThresh, upperThresh)');
    end

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    matInfo = dir(fullfile(inputDir, '*.mat'));
    if isempty(matInfo)
        error('No .mat files found in %s', inputDir);
    end

    for f = 1:numel(matInfo)
        filePath = fullfile(inputDir, matInfo(f).name);
        S = load(filePath);
        rootName = fieldnames(S);  % Ex: {'All_Subjects_6C'}
        allSubj  = S.(rootName{1});
        newStruct = struct();

        subjNames = fieldnames(allSubj);

        % First pass: collect peak-to-peak per channel across subjects
        allPtP = containers.Map();  % Map: 'cond_trigger_ch' → values

        %{
        for s = 1:numel(subjNames)
            subj = subjNames{s};
            %condNames = fieldnames(allSubj.(subj));
            condNames = fieldnames(allSubj);
            for i = 1:numel(condNames)
                cond = condNames{i};
                %trigNames = fieldnames(allSubj.(subj).(cond));
                trigNames = fieldnames(allSubj.(cond));
                for t = 1:numel(trigNames)
                    trig = trigNames{t};
                    %disp(trig);
                    %disp(fieldnames(allSubj.(cond)));
                    %data = allSubj.(subj).(cond).(trig).epoch_avg;
                    data = allSubj.(cond).(trig).epoch_avg;
                    for ch = 1:size(data, 1)
                        ptp = max(data(ch, :)) - min(data(ch, :));
                        key = sprintf('%s_%s_%d', cond, trig, ch);
                        if ~isKey(allPtP, key)
                            allPtP(key) = ptp;
                        else
                            allPtP(key) = [allPtP(key), ptp];
                        end
                    end
                end
            end
        end
        %}

        for s = 1:numel(subjNames)
            subj = subjNames{s};
            condNames = fieldnames(allSubj);
            for i = 1:numel(condNames)
                cond = condNames{i};
                trigNames = fieldnames(allSubj.(cond));
                for t = 1:numel(trigNames)
                    trig = trigNames{t};
                    data = allSubj.(cond).(trig).epoch_avg;
                    for ch = 1:size(data, 1)
                        ptp = max(data(ch, :)) - min(data(ch, :));
                        key = sprintf('%s_%s_%d', cond, trig, ch);
                        if ~isKey(allPtP, key)
                            allPtP(key) = ptp;
                        else
                            allPtP(key) = [allPtP(key), ptp];
                        end
                    end
                end
            end
        end

        % Compute thresholds per channel
        ptpThresh = containers.Map();
        keys = allPtP.keys;
        for k = 1:numel(keys)
            key = keys{k};
            vals = allPtP(key);
            lowerCut = prctile(vals, lowerThresh);
            upperCut = prctile(vals, 100 - upperThresh);
            ptpThresh(key) = [lowerCut, upperCut];
        end

        % Second pass: apply cleaning
        
        for s = 1:numel(subjNames)
            subj = subjNames{s};
            %newStruct.(subj) = struct();
            newStruct = struct();
            %condNames = fieldnames(allSubj.(subj));
            condNames = fieldnames(allSubj);
            for i = 1:numel(condNames)
                cond = condNames{i};
                newStruct.(cond) = struct();
                %trigNames = fieldnames(allSubj.(subj).(cond));
                trigNames = fieldnames(allSubj.(cond));
                for t = 1:numel(trigNames)
                    trig = trigNames{t};
                    %srcDat = allSubj.(subj).(cond).(trig);
                    srcDat = allSubj.(cond).(trig);
                    data = srcDat.epoch_avg;
                    nf = srcDat.num_files;

                    for ch = 1:size(data, 1)
                        ptp = max(data(ch, :)) - min(data(ch, :));
                        key = sprintf('%s_%s_%d', cond, trig, ch);
                        thresh = ptpThresh(key);
                        if ptp < thresh(1) || ptp > thresh(2)
                            data(ch, :) = 0;
                            nf(ch) = 0;
                        end
                    end

                    newStruct.(cond).(trig).epoch_avg = data;
                    newStruct.(cond).(trig).num_files = nf;
                end
            end
        end

        % Save cleaned file
        [~, baseName, ~] = fileparts(matInfo(f).name);
        structOutName = [rootName{1}(1:end-2), 'Clean'];  % Ex: All_Subjects_6C → All_Subjects_6Clean
        outPath = fullfile(outputDir, [structOutName, '.mat']);
        tempStruct = struct();
        tempStruct.(structOutName) = newStruct;
        save(outPath, '-struct', 'tempStruct', '-v7.3');
        disp(['Saved: ', outPath]);
    end
end