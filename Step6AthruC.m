function Step6AthruC(sourceFolder, mainDestFolders, baseDestFolder, destSubFolder, plotBool, upperThreshold, zScoreLimit, flatStdThresh)

%function Step6AthruC(sourceFolder, destFolder, destSubFolder, plotBool, upperThreshold, zScoreLimit, flatStdThresh)
    if nargin < 5
        error('Source and destination folders (and graphing instruction) must be specified.')
    end
    if nargin < 6
        upperThreshold = 100E-6;
    end
    if nargin < 7
        zScoreLimit = 6.5;
    end
    if nargin < 8
        flatStdThresh = 5e-8;
    end

    files = dir(fullfile(sourceFolder, '*.mat'));

    destFolderA = mainDestFolders{1}; if ~exist(destFolderA, 'dir'), mkdir(destFolderA); end
    destFolderB = mainDestFolders{2}; if ~exist(destFolderB, 'dir'), mkdir(destFolderB); end
    destFolderC = mainDestFolders{3}; if ~exist(destFolderC, 'dir'), mkdir(destFolderC); end

    subjChannTypes = {'Total Good', 'Failed peak-to-peak', 'Failed standard deviation', 'Failed active', ...
    'Failed peak-to-peak and standard deviation', 'Failed peak-to-peak and active', ...
    'Failed active and standard deviation', 'Failed all', 'Total Bad'};
    
    outputCSVChann = fullfile(baseDestFolder, 'Output_Files', destSubFolder, 'channel_failure_summary.csv');

    %{
    % Create blank CSV file (and its folders if needed)
    if ~exist(fileparts(outputCSVChann), 'dir')
        mkdir(fileparts(outputCSVChann));
    end
    %}

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

                goodTrig = includeTrigger(condition, trigger);

                blockTotData = zeros(63,1051);
                blockTotChannels = zeros(63,1);

                for k = 1:length(blockNames)
                    block = blockNames{k};

                    epochNames = fieldnames(structData.(condition).(trigger).(block));

                    epTotData = zeros(63,1051);
                    epTotChannels = zeros(63,1);
                    
                    if plotBool
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

                        if goodTrig
                            subjGoodAns = subjGoodAns + 1;
                        else
                            subjBadAns = subjBadAns + 1;
                            continue; % VERY IMPORTANT
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
                        % Count how many channels passed or failed each combination of criteria
                        allPass = passMatrixDiff & passMatrixStd & passMatrixActive; passArr{end+1} = allPass;
                        failPeak = ~passMatrixDiff & passMatrixStd & passMatrixActive; passArr{end+1} = failPeak;
                        failStd = passMatrixDiff & ~passMatrixStd & passMatrixActive; passArr{end+1} = failStd;
                        failActive = passMatrixDiff & passMatrixStd & ~passMatrixActive; passArr{end+1} = failActive;
                        failPeakStd = ~passMatrixDiff & ~passMatrixStd & passMatrixActive; passArr{end+1} = failPeakStd;
                        failPeakActive = ~passMatrixDiff & passMatrixStd & ~passMatrixActive; passArr{end+1} = failPeakActive;
                        failStdActive = passMatrixDiff & ~passMatrixStd & ~passMatrixActive; passArr{end+1} = failStdActive;
                        allFail = ~passMatrixDiff & ~passMatrixStd & ~passMatrixActive; passArr{end+1} = allFail;
                        
                        tempChannCounts = zeros(1, length(subjChannCounts));
                        numGood = sum(allPass); tempChannCounts(1) = tempChannCounts(1) + numGood;
                        countFailPeak = sum(failPeak); tempChannCounts(2) = tempChannCounts(2) + countFailPeak;
                        countFailStd = sum(failStd); tempChannCounts(3) = tempChannCounts(3) + countFailStd;
                        countFailActive = sum(failActive); tempChannCounts(4) = tempChannCounts(4) + countFailActive;
                        countFailPeakStd = sum(failPeakStd); tempChannCounts(5) = tempChannCounts(5) + countFailPeakStd;
                        countFailPeakActive = sum(failPeakActive); tempChannCounts(6) = tempChannCounts(6) + countFailPeakActive;
                        countFailStdActive = sum(failStdActive); tempChannCounts(7) = tempChannCounts(7) + countFailStdActive;
                        countAllFail = sum(allFail); tempChannCounts(8) = tempChannCounts(8) + countAllFail;
                        numBad = 63 - numGood; tempChannCounts(9) = tempChannCounts(9) + numBad;

                        subjChannCounts = subjChannCounts + tempChannCounts; % numBad was already counted
                        if (sum(tempChannCounts) - numBad) ~= 63
                            error('Counting bad channels has not worked.')
                        end
                        
                        subjBadChanns = subjBadChanns + numBad;
                        subjGoodChanns = subjGoodChanns + numGood;
                        
                        if plotBool

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
                                    lineSize = 0.1;
                                else
                                    lineSize = 2;
                                end
                                if ~isempty(dataToGraph)
                                    plot(ts, dataToGraph, 'LineWidth', lineSize, 'Color', lineColor);
                                end
                            end
                            plot(ts, std(dataFiltMicro), 'LineWidth', 2, 'Color', [0, 1, 1]);  % GFP in cyan
                            title([block ' - ' epoch, ' - ', num2str(passMatrixDiff), ' above'], 'Interpreter', 'none');
                            xlabel('Time (s)');
                            ylabel('µV');
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

                    if goodTrig

                        epAvgData = epTotData ./ epTotChannels;
                        epAvgData(epTotChannels == 0, :) = 0;
    
                        newStructDataB.(condition).(trigger).(block).epoch_avg = epAvgData;
                        newStructDataB.(condition).(trigger).(block).num_files = epTotChannels;

                        if plotBool
                            dirFolderGr = fullfile(baseDestFolder, 'Step7_IndivGraphs_Output', destSubFolder, nameOnly, condition);
                            if ~exist(dirFolderGr, 'dir')
                                mkdir(dirFolderGr);
                            end
                            savePathGr = fullfile(dirFolderGr, [block, '_', trigger, '_Subplots.png']);
                            exportgraphics(figSub, savePathGr);
                            close(figSub);
                        end
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
    fprintf(txtfile, ['Peak to peak upper limit: ', num2str(upperThreshold * 1E6), 'µV.\n']);
    fprintf(txtfile, ['Standard deviation lower limit : ', num2str(flatStdThresh * 1E6), 'µV.\n']);
    fprintf(txtfile, ['Z-score upper limit: ', num2str(zScoreLimit), '.\n']);
    fclose(txtfile);
    disp(['Saved summary stats to CSV: ', outputTXT]);
    disp('');
    
end

function includeBool = includeTrigger(condition, trigger)

% See if this is an active condition
isActiveCond = strncmp(condition, 'Attend', 6);

% If Passive:
if ~isActiveCond
    includeBool = true;
    return;
end

% If Active:
%           To 60L: To 30L: To 0:   To 30R: To 60R:         
% From 60L: 1       2       3       4       5
% From 30L: 6       7       8       9       10
% From 0:   11      12      13      14      15
% From 30R: 16      17      18      19      20
% From 60R: 21      22      23      24      25

locMatrix = reshape(1:25, [5, 5])'; 
locLabels = {'60L', '30L', '0', '30R', '60R'}; % Column titles

attendLabel = condition(7:end);
trigParts = split(trigger, '_');
triggerNum = trigParts{2};
triggerTag = trigParts{3};

% Find the column number of this trigger in the location matrix
[~, locIdx] = find(locMatrix == str2double(triggerNum)); % Ex. 5 for trigger 25
soundLoc = locLabels{locIdx}; % Ex. sound was at location 30R

if soundLoc == attendLabel
    if triggerTag == 'Y'; includeBool = true; return;
    elseif triggerTag == 'N'; includeBool = false; return;
    end
else
    if triggerTag == 'Y'; includeBool = false; return;
    elseif triggerTag == 'N'; includeBool = true; return;
    end
end

end
