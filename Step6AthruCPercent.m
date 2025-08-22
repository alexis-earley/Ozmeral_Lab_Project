function Step6AthruCPercent(sourceFolder, combinedMatrixDir, destFolder, destSubFolder, pctLimits)

    % TO DO: Do seperate thresholding for each individual channel
    % Look inside the directory for the combined matrix file
    matrixFileInfo = dir(fullfile(combinedMatrixDir, '*Combined_Channels_6AA.mat'));
    if isempty(matrixFileInfo)
        error('No Combined_Channels_6AA.mat file found in %s', combinedMatrixDir);
    elseif numel(matrixFileInfo) > 1
        warning('Multiple Combined_Channels_6AA.mat files found, using the first one.');
    end
    combinedMatrixFile = fullfile(matrixFileInfo(1).folder, matrixFileInfo(1).name);

    % Load the combined peak-to-peak matrix (global thresholds for all subjects)
    tmp = load(combinedMatrixFile);
    if ~isfield(tmp, 'Combined_Channels_6AA')
        error('File %s does not contain variable Combined_Channels_6AA', combinedMatrixFile);
    end
    Combined_Channels_6AA = tmp.Combined_Channels_6AA;

    % Calculate thresholds from the global matrix
    lowerThresh = prctile(Combined_Channels_6AA(:), pctLimits(1) * 100);
    upperThresh = prctile(Combined_Channels_6AA(:), pctLimits(2) * 100);

    % Make output folders
    files = dir(fullfile(sourceFolder, '*.mat'));
    destFolderA = fullfile(destFolder, 'Step6A_Output', destSubFolder);
    if ~exist(destFolderA, 'dir'), mkdir(destFolderA); end
    destFolderB = fullfile(destFolder, 'Step6B_Output', destSubFolder);
    if ~exist(destFolderB, 'dir'), mkdir(destFolderB); end
    destFolderC = fullfile(destFolder, 'Step6C_Output', destSubFolder);
    if ~exist(destFolderC, 'dir'), mkdir(destFolderC); end

    % Channel failure CSV
    subjChannTypes = {'Total Good', 'Total Bad'};
    outputCSVChann = fullfile(destFolder, 'Output_Files', destSubFolder, 'channel_failure_summary.csv');
    if ~exist(fileparts(outputCSVChann), 'dir'), mkdir(fileparts(outputCSVChann)); end
    fChann = fopen(outputCSVChann, 'w');
    if fChann == -1, error('Failed to open %s for writing.', outputCSVChann); end
    fprintf(fChann, 'Subject,%s,%s\n', subjChannTypes{:});

    totGoodChanns = 0;
    totBadChanns = 0;

    % Process each subject
    for j = 1:length(files)
        fileName = files(j).name;
        sourcePath = fullfile(sourceFolder, fileName);

        disp(['Processing file: ', fileName]);
        data = load(sourcePath);
        varName = fieldnames(data);
        topVarName = varName{1};
        structData = data.(topVarName);

        [~, nameOnly, ~] = fileparts(fileName);

        newStructDataA = struct();
        newStructDataB = struct();
        newStructDataC = struct();

        subjGoodChanns = 0;
        subjBadChanns = 0;

        condNames = fieldnames(structData);
        for i = 1:length(condNames)
            condition = condNames{i};
            triggerNames = fieldnames(structData.(condition));

            for j2 = 1:length(triggerNames)
                trigger = triggerNames{j2};
                blockNames = fieldnames(structData.(condition).(trigger));

                goodTrig = includeTrigger(condition, trigger);
                blockTotData = zeros(63,1051);
                blockTotChannels = zeros(63,1);

                for k = 1:length(blockNames)
                    block = blockNames{k};
                    epochNames = fieldnames(structData.(condition).(trigger).(block));
                    epTotData = zeros(63,1051);
                    epTotChannels = zeros(63,1);

                    for m = 1:length(epochNames)
                        epoch = epochNames{m};
                        matrix = structData.(condition).(trigger).(block).(epoch);

                        if ~(isnumeric(matrix) && ismatrix(matrix))
                            error('Matrix is not numeric or is not a 2D matrix.');
                        end

                        if ~goodTrig
                            continue;
                        end

                        % Reduce to 63 channels
                        nRows = size(matrix, 1);
                        if nRows == 63
                            reducedChannels = matrix;
                        elseif nRows == 70 || nRows == 88
                            rowsToDelete = [32, 65:nRows];
                            reducedChannels = matrix(setdiff(1:nRows, rowsToDelete), :);
                        elseif nRows == 69
                            rowsToDelete = 64:nRows;
                            reducedChannels = matrix(setdiff(1:nRows, rowsToDelete), :);
                        else
                            error(['Matrix "', epoch, '" has unexpected row count: ', num2str(nRows)]);
                        end

                        % Apply global thresholds
                        channelsMax = max(reducedChannels, [], 2);
                        channelsMin = min(reducedChannels, [], 2);
                        channelsDiff = channelsMax - channelsMin;
                        passMask = (channelsDiff >= lowerThresh) & (channelsDiff <= upperThresh);
                        allPass = double(passMask);

                        % Count
                        numGood = sum(allPass);
                        numBad = 63 - numGood;
                        subjGoodChanns = subjGoodChanns + numGood;
                        subjBadChanns = subjBadChanns + numBad;

                        % Apply mask
                        goodData = reducedChannels .* allPass;

                        % Save Step6A
                        newStructDataA.(condition).(trigger).(block).(epoch).epoch_avg = goodData;
                        newStructDataA.(condition).(trigger).(block).(epoch).num_files = allPass;

                        % Accumulate for Step6B/C
                        epTotData = epTotData + goodData;
                        epTotChannels = epTotChannels + allPass;
                        blockTotData = blockTotData + goodData;
                        blockTotChannels = blockTotChannels + allPass;
                    end

                    if goodTrig
                        epAvgData = epTotData ./ epTotChannels;
                        epAvgData(epTotChannels == 0, :) = 0;
                        newStructDataB.(condition).(trigger).(block).epoch_avg = epAvgData;
                        newStructDataB.(condition).(trigger).(block).num_files = epTotChannels;
                    end
                end

                if goodTrig
                    blockAvgData = blockTotData ./ blockTotChannels;
                    blockAvgData(blockTotChannels == 0, :) = 0;
                    newStructDataC.(condition).(trigger).epoch_avg = blockAvgData;
                    newStructDataC.(condition).(trigger).num_files = blockTotChannels;
                end
            end
        end

        fprintf(fChann, '%s,%d,%d\n', nameOnly, subjGoodChanns, subjBadChanns);
        totGoodChanns = totGoodChanns + subjGoodChanns;
        totBadChanns = totBadChanns + subjBadChanns;

        % Wrap with subject name before saving
        tempStruct = struct();
        tempStruct.([nameOnly '_6A']) = newStructDataA;
        save(fullfile(destFolderA, [nameOnly '_6A.mat']), '-struct', 'tempStruct', '-v7.3');

        tempStruct = struct();
        tempStruct.([nameOnly '_6B']) = newStructDataB;
        save(fullfile(destFolderB, [nameOnly '_6B.mat']), '-struct', 'tempStruct', '-v7.3');

        tempStruct = struct();
        tempStruct.([nameOnly '_6C']) = newStructDataC;
        save(fullfile(destFolderC, [nameOnly '_6C.mat']), '-struct', 'tempStruct', '-v7.3');
    end

    fclose(fChann);

    % Save global thresholds
    outputTXT = fullfile(destFolder, 'Output_Files', destSubFolder, 'limit_stats.txt');
    txtfile = fopen(outputTXT, 'w');
    fprintf(txtfile, 'Percentile limits: %.2f - %.2f\n', pctLimits(1), pctLimits(2));
    fprintf(txtfile, 'Lower threshold (µV): %.3f\n', lowerThresh * 1e6);
    fprintf(txtfile, 'Upper threshold (µV): %.3f\n', upperThresh * 1e6);
    fclose(txtfile);
    disp(['Saved percentile limits to: ', outputTXT]);
end

function includeBool = includeTrigger(condition, trigger)
    isActiveCond = strncmp(condition, 'Attend', 6);
    if ~isActiveCond
        includeBool = true;
        return;
    end

    locMatrix = reshape(1:25, [5, 5])';
    locLabels = {'60L', '30L', '0', '30R', '60R'};

    attendLabel = condition(7:end);
    trigParts = split(trigger, '_');
    triggerNum = trigParts{2};
    triggerTag = trigParts{3};

    [~, locIdx] = find(locMatrix == str2double(triggerNum));
    soundLoc = locLabels{locIdx};

    if strcmp(soundLoc, attendLabel)
        includeBool = strcmp(triggerTag, 'Y');
    else
        includeBool = strcmp(triggerTag, 'N');
    end
end