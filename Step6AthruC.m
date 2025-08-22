function Step6AthruC(sourceFolder, mainDestFolders, baseDestFolder, destSubFolder, plotBool6A, plotBool6B, plotBool6C, upperThreshold, zScoreLimit, flatStdThresh, removeDiags, removeNos)

%function Step6AthruC(sourceFolder, destFolder, destSubFolder, plotBool, upperThreshold, zScoreLimit, flatStdThresh)
    if nargin < 7
        error('Source/dest folders and plotting flags (6A/6B/6C) must be specified.')
    end
    if nargin < 8 || isempty(upperThreshold)
        upperThreshold = 100E-6;
    end
    if nargin < 9 || isempty(zScoreLimit)
        zScoreLimit = 6.5;
    end
    if nargin < 10 || isempty(flatStdThresh)
        flatStdThresh = 5e-8;
    end

    files = dir(fullfile(sourceFolder, '*.mat'));

    destFolderA = mainDestFolders{1}; if ~exist(destFolderA, 'dir'), mkdir(destFolderA); end
    destFolderB = mainDestFolders{2}; if ~exist(destFolderB, 'dir'), mkdir(destFolderB); end
    destFolderC = mainDestFolders{3}; if ~exist(destFolderC, 'dir'), mkdir(destFolderC); end

    subjChannTypes = {'Total Good','Failed peak-to-peak','Failed standard deviation','Failed active', ...
    'Failed peak-to-peak and standard deviation','Failed peak-to-peak and active', ...
    'Failed active and standard deviation','Failed all','Zeroed (>=50% bad)','Total Bad'}; % NEW

    
    outputCSVChann = fullfile(baseDestFolder, 'Output_Files', destSubFolder, 'channel_failure_summary.csv');
   
    % Create blank CSV file (and its folders if needed)
    if ~exist(fileparts(outputCSVChann), 'dir')
        mkdir(fileparts(outputCSVChann));
    end
    

    fChann = fopen(outputCSVChann, 'w');
    % Write header
    fprintf(fChann, 'Subject');
    for i = 1:length(subjChannTypes)
        fprintf(fChann, ',%s', subjChannTypes{i});
    end
    fprintf(fChann, '\n');

    subjRespStats = containers.Map();
    subjChanStats = containers.Map();
    totGoodChanns = 0;
    totBadChanns = 0;

    for j = 1:length(files)
        fileName = files(j).name;
        sourcePath = fullfile(sourceFolder, fileName);

        disp(['Processing file: ', fileName]);
        data = load(sourcePath);
        varName = fieldnames(data);
        topVarName = varName{1};
        structData = data.(topVarName);
        disp(['Loaded struct variable: ', topVarName]);
        fprintf('\n');

        [~, nameOnly, ~] = fileparts(fileName);
        outputTagA = [nameOnly '_6A'];
        destinationPathA = fullfile(destFolderA, [outputTagA '.mat']);
        outputTagB = [nameOnly '_6B'];
        destinationPathB = fullfile(destFolderB, [outputTagB '.mat']);
        outputTagC = [nameOnly '_6C'];
        destinationPathC = fullfile(destFolderC, [outputTagC '.mat']);

        tempStruct = struct(); % Clear for each new files
        newStructDataA = struct();
        newStructDataB = struct();
        newStructDataC = struct();

        % holders for new subplot behavior
        % For 6B: collect per-block epAvgData so we can subplot per trigger later
        plotStoreB = struct(); % plotStoreB.(condition).(trigger).(block) = epAvgData
        % For 6C: collect per-trigger blockAvgData so we can subplot per condition later
        plotStoreC = struct(); % plotStoreC.(condition).(trigger) = blockAvgData

        subjGoodChanns = 0;
        subjBadChanns = 0;
        subjChannCounts = zeros(1,length(subjChannTypes));
        subjGoodAns = 0;
        subjBadAns = 0;

        condNames = fieldnames(structData);

        for i = 1:length(condNames)
            condition = condNames{i};
            triggerNames = fieldnames(structData.(condition));

            for j2 = 1:length(triggerNames)
                trigger = triggerNames{j2};
                blockNames = fieldnames(structData.(condition).(trigger));

                goodTrig = IncludeTrigger(condition, trigger, removeDiags, removeNos);

                blockTotData = zeros(63,1051);
                blockTotChannels = zeros(63,1);

                for k = 1:length(blockNames)
                    block = blockNames{k};

                    epochNames = fieldnames(structData.(condition).(trigger).(block));

                    epTotData = zeros(63,1051);
                    epTotChannels = zeros(63,1);
                    
                    if plotBool6A
                        % Subplot
                        numEpochs = length(epochNames);
                        subplotCols = ceil(sqrt(numEpochs));
                        subplotRows = ceil(numEpochs / subplotCols);
                        figSub = figure('Visible', 'off', 'Position', [100, 100, 2000, 1200]);
                    end

                    for m = 1:length(epochNames)                      

                        epoch = epochNames{m};
                        matrix = structData.(condition).(trigger).(block).(epoch);

                        if ~(isnumeric(matrix) && ismatrix(matrix))
                            error('Matrix is not numeric or is not a 2D matrix.');
                        end

                        % See if this is an active condition
                        isActiveCond = strncmp(condition, 'Attend', 6);

                        if goodTrig == 1
                            if isActiveCond
                                subjGoodAns = subjGoodAns + 1;
                            end
                        elseif goodTrig == 0
                            if isActiveCond
                                subjBadAns = subjBadAns + 1;
                            end
                            continue; % VERY IMPORTANT
                        else % goodTrig == -1
                            continue;
                        end

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
                            error(['Matrix "', epoch, '" has ', num2str(nRows), ...
                                   ' rows (expected 63, 69, 70, or 88).']);
                        end
  
                        % Omit channels if peak-to-peak difference is too large  
                        channelsMax = max((reducedChannels), [], 2);
                        channelsMin = min((reducedChannels), [], 2);
                        channelsDiff = channelsMax - channelsMin;
                        passMatrixDiff = double(channelsDiff <= upperThreshold);
                        
                        % Omit channels if standard deviation is too high
                        channelStd = std(reducedChannels, 0, 2);  % Std deviation across time for each channel
                        meanStd = mean(channelStd, 'omitnan');
                        stdOfStd = std(channelStd, 'omitnan');       
                        zScores = abs(channelStd - meanStd) / stdOfStd;
                        passMatrixStd = double(zScores <= zScoreLimit);
                        
                        % Omit channels if too flat
                        passMatrixActive = double(channelStd >= flatStdThresh);      
                        
                        passArr = {};
                        % (1) Count how many channels passed all criteria
                        allPass = passMatrixDiff & passMatrixStd & passMatrixActive; 
                        passArr{end+1} = allPass;
                        
                        % Snapshot PRE-wipe masks (for reason counts)
                        pre_allPass = allPass;
                        pre_failPeak = ~passMatrixDiff &  passMatrixStd &  passMatrixActive;
                        pre_failStd =  passMatrixDiff & ~passMatrixStd &  passMatrixActive;
                        pre_failActive =  passMatrixDiff &  passMatrixStd & ~passMatrixActive;
                        pre_failPeakStd = ~passMatrixDiff & ~passMatrixStd &  passMatrixActive;
                        pre_failPeakActive = ~passMatrixDiff &  passMatrixStd & ~passMatrixActive;
                        pre_failStdActive =  passMatrixDiff & ~passMatrixStd & ~passMatrixActive;
                        pre_allFail = ~passMatrixDiff & ~passMatrixStd & ~passMatrixActive;
                        pre_numGood = sum(pre_allPass);
                        pre_numBad = 63 - pre_numGood;
                        
                        % (2) Majority wipe: if ≥ half fail any check, zero the rest
                        majorityWipe = sum(~pre_allPass) >= (size(pre_allPass,1) / 2);
                        if majorityWipe
                            allPass(:) = 0; % post-wipe: everything is bad in this epoch
                        end
                        
                        % Build fail masks for plotting from PRE-wipe logic
                        failPeak = pre_failPeak; passArr{end+1} = failPeak;
                        failStd = pre_failStd; passArr{end+1} = failStd;
                        failActive = pre_failActive; passArr{end+1} = failActive;
                        failPeakStd = pre_failPeakStd; passArr{end+1} = failPeakStd;
                        failPeakActive = pre_failPeakActive; passArr{end+1} = failPeakActive;
                        failStdActive = pre_failStdActive; passArr{end+1} = failStdActive;
                        allFail = pre_allFail; passArr{end+1} = allFail;
                        
                        % (3) Totals from POST-wipe mask; reasons from PRE-wipe masks
                        tempChannCounts = zeros(1, length(subjChannCounts));
                        numGood = sum(allPass); tempChannCounts(1) = tempChannCounts(1) + numGood;
                        
                        countFailPeak = sum(pre_failPeak); tempChannCounts(2) = tempChannCounts(2) + countFailPeak;
                        countFailStd = sum(pre_failStd); tempChannCounts(3) = tempChannCounts(3) + countFailStd;
                        countFailActive = sum(pre_failActive); tempChannCounts(4) = tempChannCounts(4) + countFailActive;
                        countFailPeakStd = sum(pre_failPeakStd); tempChannCounts(5) = tempChannCounts(5) + countFailPeakStd;
                        countFailPeakActive = sum(pre_failPeakActive); tempChannCounts(6) = tempChannCounts(6) + countFailPeakActive;
                        countFailStdActive = sum(pre_failStdActive); tempChannCounts(7) = tempChannCounts(7) + countFailStdActive;
                        countAllFail = sum(pre_allFail); tempChannCounts(8) = tempChannCounts(8) + countAllFail;
                        
                        numBad = 63 - numGood; tempChannCounts(10) = tempChannCounts(10) + numBad;
                        
                        % Bucket 10 = extra zeroed channels caused by the wipe (post - pre)
                        if majorityWipe
                            extraZeroed = numBad - pre_numBad; % equals 63 - pre_numBad
                            tempChannCounts(9) = tempChannCounts(9) + extraZeroed;
                        end
                        
                        % (4) Accumulate + sanity check (reasons + extraZeroed == Total Bad)
                        subjChannCounts = subjChannCounts + tempChannCounts; % numBad already included
                        if (sum(tempChannCounts(2:8)) + tempChannCounts(9)) ~= tempChannCounts(10)
                            error('Counting bad channels has not worked.')
                        end
                        
                        subjBadChanns = subjBadChanns + numBad;
                        subjGoodChanns = subjGoodChanns + numGood;


                        if plotBool6A
                            subplot(subplotRows, subplotCols, m);
                            hold on;
                            ts = linspace(-0.1, 2.0, size(reducedChannels, 2));
    
                            colorArr = {[0, 0, 0]; [1, 0, 0]; [0, 0, 1]; [1, 1, 0]; [0.5, 0, 0.5]; ...
                                [1, 0.5, 0]; [0, 0.5, 0]; [0.6, 0.3, 0]};
    
                            % Total good - [0, 0, 0] - black 
                            % Failed peak-to-peak - [1, 0, 0] - red 
                            % Failed standard deviation - [0, 0, 1] - blue
                            % Failed active - [1, 1, 0] - yellow
                            % Failed peak-to-peak and standard deviation - [0.5, 0, 0.5] - purple
                            % Failed peak-to-peak and active - [1, 0.5, 0] - orange
                            % Failed active and standard deviation - [0, 0.5, 0] - green
                            % Failed all - [0.6, 0.3, 0] - brown
    
                            dataFiltMicro = reducedChannels * 1E6;
     
                            for ch = 1:length(passArr)
                                dataSorted = dataFiltMicro .* passArr{ch};
                                nonZeroRows = any(dataSorted, 2);  % Find rows with any non-zero values
                                dataToGraph = dataSorted(nonZeroRows, :);
                                lineColor = colorArr{ch};
    
                                if ch == 1
                                    lineSize = 0.8;   % slightly thicker so not too faint
                                else
                                    lineSize = 2;
                                end
                                if ~isempty(dataToGraph)
                                    plot(ts, dataToGraph, 'LineWidth', lineSize, 'Color', lineColor);
                                end
                            end
                            plot(ts, std(dataFiltMicro), 'LineWidth', 2, 'Color', [0, 1, 1]);  % GFP in cyan

                            % Descriptive subplot title for 6A 
                            numPk2PkBad = 63 - sum(passMatrixDiff(:));
                            subTitle6A = sprintf('%s | %s | %s | %s | %s | Pk2Pk>thresh: %d', ...
                                nameOnly, condition, trigger, block, epoch, numPk2PkBad);
                            title(subTitle6A, 'Interpreter', 'none');

                            xlabel('Time (s)');
                            ylabel('\muV');
                            xlim([-0.1, 2]);
                        end

                        goodData = reducedChannels .* allPass;

                        newStructDataA.(condition).(trigger).(block).(epoch).epoch_avg = goodData;
                        newStructDataA.(condition).(trigger).(block).(epoch).num_files = allPass;

                        epTotData = epTotData + goodData;
                        epTotChannels = epTotChannels + allPass;

                        blockTotData = blockTotData + goodData;
                        blockTotChannels = blockTotChannels + allPass;
                    end

                    if goodTrig == 1
                        epAvgData = epTotData ./ epTotChannels;
                        epAvgData(epTotChannels == 0, :) = 0;
    
                        newStructDataB.(condition).(trigger).(block).epoch_avg = epAvgData;
                        newStructDataB.(condition).(trigger).(block).num_files = epTotChannels;

                        % store for 6B plotting by trigger (subplots per block)
                        if plotBool6B
                            if ~isfield(plotStoreB, condition), plotStoreB.(condition) = struct(); end
                            if ~isfield(plotStoreB.(condition), trigger), plotStoreB.(condition).(trigger) = struct(); end
                            plotStoreB.(condition).(trigger).(block) = epAvgData;
                        end

                        % ---- Save 6A per-block/epoch subplots figure with descriptive name ----
                        if plotBool6A
                            dirFolderGrA = fullfile(baseDestFolder, 'Step7_IndivGraphs_Output_6A', destSubFolder, nameOnly, condition, trigger);
                            if ~exist(dirFolderGrA, 'dir'), mkdir(dirFolderGrA); end
                            figTitle6A = sprintf('Step6A | %s | %s | %s | %s | epoch subplots', nameOnly, condition, trigger, block);
                            sgtitle(figSub, figTitle6A, 'Interpreter', 'none');
                            file6A = sprintf('Step6A__%s__%s__%s__%s__EpochSubplots.png', ...
                                SafeFile(nameOnly), SafeFile(condition), SafeFile(trigger), SafeFile(block));
                            savePathGrA = fullfile(dirFolderGrA, file6A);
                            exportgraphics(figSub, savePathGrA);
                            close(figSub);
                        end
                    end
                end

                if goodTrig == 1
                    blockAvgData = blockTotData ./ blockTotChannels;
                    blockAvgData(blockTotChannels == 0, :) = 0;
    
                    newStructDataC.(condition).(trigger).epoch_avg = blockAvgData;
                    newStructDataC.(condition).(trigger).num_files = blockTotChannels;

                    % store for 6C plotting by condition (subplots per trigger)
                    if plotBool6C
                        if ~isfield(plotStoreC, condition), plotStoreC.(condition) = struct(); end
                        plotStoreC.(condition).(trigger) = blockAvgData;
                    end
                end
            end
            % after finishing all triggers for this condition, emit 6C figure if requested
            if plotBool6C && isfield(plotStoreC, condition)
                dirFolderGrC = fullfile(baseDestFolder, 'Step7_IndivGraphs_Output_6C', destSubFolder, nameOnly);
                if ~exist(dirFolderGrC, 'dir')
                    mkdir(dirFolderGrC);
                end
                trigListC = fieldnames(plotStoreC.(condition));
                nSubsC = numel(trigListC);
                subplotColsC = ceil(sqrt(nSubsC));
                subplotRowsC = ceil(nSubsC / subplotColsC);
            
                figC = figure('Visible', 'off', 'Position', [100, 100, 2000, 1200]);
                for tIdx = 1:nSubsC
                    trigNameC = trigListC{tIdx};
                    dataC = plotStoreC.(condition).(trigNameC);
                    ts = linspace(-0.1, 2.0, size(dataC, 2));
            
                    subplot(subplotRowsC, subplotColsC, tIdx);
                    hold on;
                    dataMicro = dataC * 1E6;
                    plot(ts, dataMicro', 'Color', [0 0 0 0.15]);         % channels
                    plot(ts, std(dataMicro), 'LineWidth', 2, 'Color', [0, 1, 1]); % GFP
                    title(trigNameC, 'Interpreter', 'none');             % <-- only trigger name
                    xlabel('Time (s)'); ylabel('\muV'); xlim([-0.1, 2]);
                end
            
                % Descriptive overall title and filename stay as-is:
                bigTitle6C = sprintf('Step6C | %s | %s | All triggers', nameOnly, condition);
                sgtitle(bigTitle6C, 'Interpreter', 'none');
            
                file6C = sprintf('Step6C__%s__%s__AllTriggers_Subplots.png', ...
                                 SafeFile(nameOnly), SafeFile(condition));
                savePathGrC = fullfile(dirFolderGrC, file6C);
                exportgraphics(figC, savePathGrC);
                close(figC);
            end


        end

        % after finishing all conditions/triggers/blocks, emit 6B figures if requested
        if plotBool6B
            condKeysB = fieldnames(plotStoreB);
            for ci = 1:numel(condKeysB)
                condB = condKeysB{ci};
                trigKeysB = fieldnames(plotStoreB.(condB));
                for ti = 1:numel(trigKeysB)
                    trigB = trigKeysB{ti};
                    dirFolderGrB = fullfile(baseDestFolder, 'Step7_IndivGraphs_Output_6B', destSubFolder, nameOnly, condB);
                    if ~exist(dirFolderGrB, 'dir')
                        mkdir(dirFolderGrB);
                    end
                    blockKeys = fieldnames(plotStoreB.(condB).(trigB));
                    nSubsB = numel(blockKeys);
                    subplotColsB = ceil(sqrt(nSubsB));
                    subplotRowsB = ceil(nSubsB / subplotColsB);

                    figB = figure('Visible', 'off', 'Position', [100, 100, 2000, 1200]);
                    for bi = 1:nSubsB
                        blk = blockKeys{bi};
                        dataB = plotStoreB.(condB).(trigB).(blk);
                        ts = linspace(-0.1, 2.0, size(dataB, 2));

                        subplot(subplotRowsB, subplotColsB, bi);
                        hold on;
                        dataMicroB = dataB * 1E6;
                        plot(ts, dataMicroB', 'Color', [0 0 0 0.15]); % channels
                        plot(ts, std(dataMicroB), 'LineWidth', 2, 'Color', [0, 1, 1]); % GFP
                        % Descriptive subplot title for 6B
                        %subTitle6B = sprintf('%s | %s | %s | %s | Block avg', nameOnly, condB, trigB, blk);
                        title(blk, 'Interpreter', 'none');
                        xlabel('Time (s)'); ylabel('\muV'); xlim([-0.1, 2]);
                    end
                    bigTitle6B = sprintf('Step6B | %s | %s | %s | All blocks', nameOnly, condB, trigB);
                    sgtitle(bigTitle6B, 'Interpreter', 'none');

                    file6B = sprintf('Step6B__%s__%s__%s__AllBlocks_Subplots.png', ...
                        SafeFile(nameOnly), SafeFile(condB), SafeFile(trigB));
                    savePathGrB = fullfile(dirFolderGrB, file6B);
                    exportgraphics(figB, savePathGrB);
                    close(figB);
                end
            end
        end

        if subjGoodChanns ~= subjChannCounts(1)
            error('subjGoodChanns is not equal to subjChannCounts(1)');
        end

        fprintf(fChann, '%s', nameOnly);
        for i = 1:length(subjChannCounts)
            subjChannType = subjChannTypes{i}; 
            subjChannCount = subjChannCounts(i);
            if subjChannCount > 0
                disp([subjChannType, ': ', num2str(subjChannCount)]);
            end
            fprintf(fChann, ',%d', subjChannCounts(i));
        end
        fprintf(fChann, '\n');
        chanPerc = (subjGoodChanns / (subjGoodChanns + subjBadChanns)) * 100;
        disp(['Percent correct: ', num2str(round(chanPerc,2)), '%']);
        fprintf('\n');

        disp(['Number of correct responses: ', num2str(subjGoodAns)]);
        disp(['Number of incorrect responses: ', num2str(subjBadAns)]);
        respPerc = (subjGoodAns / (subjGoodAns + subjBadAns)) * 100;
        disp(['Percent correct: ', num2str(round(respPerc,2)), '%']);
        fprintf('\n');

        % Save subject data to maps
        subjRespStats(nameOnly) = [subjGoodAns, subjBadAns, respPerc];
        subjChanStats(nameOnly) = [subjGoodChanns, subjBadChanns, chanPerc];

        totGoodChanns = totGoodChanns + subjGoodChanns;
        totBadChanns = totBadChanns + subjBadChanns;
       
        % Save updated struct A - cleaned data
        tempStruct.(outputTagA) = newStructDataA;
        save(destinationPathA, '-struct', 'tempStruct', '-v7.3');
        disp(['Saved updated file to: ', destinationPathA]);
        
        % Save updated struct B - block average
        tempStruct = struct();  % Reset struct
        tempStruct.(outputTagB) = newStructDataB;
        save(destinationPathB, '-struct', 'tempStruct', '-v7.3');
        disp(['Saved updated file to: ', destinationPathB]);

        % Save updated struct C - trigger average
        tempStruct = struct();  % Reset struct
        tempStruct.(outputTagC) = newStructDataC;
        save(destinationPathC, '-struct', 'tempStruct', '-v7.3');
        disp(['Saved updated file to: ', destinationPathC]);
        fprintf('\n');
        

    end
    
    % Summary
    disp('All subject files processed and saved to new directory.');
    disp(['Number of total good channels: ', num2str(totGoodChanns)]);
    disp(['Number of total bad channels: ', num2str(totBadChanns)]);
    chanPerc = (totGoodChanns / (totGoodChanns + totBadChanns)) * 100;
    disp(['Percent correct: ', num2str(round(chanPerc,2)), '%']);
    subjChanStats('Total') = [subjGoodChanns, subjBadChanns, chanPerc];
    fprintf('\n');
    
    % Close channels description file
    fclose(fChann);

    % Save subject_response_stats.csv
    responseKeys = subjRespStats.keys;
    outputCSV1 = fullfile(baseDestFolder, 'Output_Files', destSubFolder, 'subject_response_stats.csv');
    csvfile1 = fopen(outputCSV1, 'w');
    fprintf(csvfile1, 'Subject, Correct Responses, Incorrect Responses, Percent Correct\n');
    for i = 1:length(responseKeys)
        key = responseKeys{i};
        vals = subjChanStats(key);
        fprintf(csvfile1, '%s,%d,%d,%.2f\n', key, vals(1), vals(2), vals(3));
    end
    fclose(csvfile1);
    disp(['Saved summary stats to CSV: ', outputCSV1]);   

    % Save subject_channel_stats.csv
    channelKeys = subjChanStats.keys;
    outputCSV2 = fullfile(baseDestFolder, 'Output_Files', destSubFolder, 'subject_channel_stats.csv');
    csvfile2 = fopen(outputCSV2, 'w');
    fprintf(csvfile2, 'Subject, Good Channels, Bad Channels, Percent Correct\n');
    for i = 1:length(channelKeys)
        key = channelKeys{i};
        vals = subjChanStats(key);
        fprintf(csvfile2, '%s,%d,%d,%.2f\n', key, vals(1), vals(2), vals(3));
    end
    fclose(csvfile2);
    disp(['Saved summary stats to CSV: ', outputCSV2]);   

    % Save limit_stats.csv
    outputTXT = fullfile(baseDestFolder, 'Output_Files', destSubFolder, 'limit_stats.txt');
    txtfile = fopen(outputTXT, 'w');
    fprintf(txtfile, ['Peak to peak upper limit: ', num2str(upperThreshold * 1E6), '\xB5V.\n']);
    fprintf(txtfile, ['Standard deviation lower limit : ', num2str(flatStdThresh * 1E6), '\xB5V.\n']);
    fprintf(txtfile, ['Z-score upper limit: ', num2str(zScoreLimit), '.\n']);
    fclose(txtfile);
    disp(['Saved summary stats to CSV: ', outputTXT]);
    disp('');
    
end