function Step7GraphSubjects(inputDir, outputDir, subplotTitle)
% Example:
%   Step7GraphSubjects(inputDir, outputDir,'Older Hearing Impaired (Unaided)')
% Input should be from Step6CNew

    % Create output directory if it doesn't exist
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    files = dir(fullfile(inputDir, '*.mat')); % Get subject files
    if isempty(files)
        error('No .mat files found in input directory.');
    end

    for i = 1:length(files)
        filePath = fullfile(inputDir, files(i).name);
        disp(['Processing: ', files(i).name]);

        % Load subject struct
        fileStruct = load(filePath);
        varNames = fieldnames(fileStruct);
        weightedStruct = fileStruct.(varNames{1}); % ex. Subject_0604_6C

        % Automatically detect available conditions
        condList = fieldnames(weightedStruct);
        numSamples = 1051;
        ts = linspace(-0.1, 2.0, numSamples);  % Time vector (in seconds)

        numConds = length(condList);
        subplotCols = 2;
        subplotRows = ceil(numConds / subplotCols);
        fig = figure('Visible', 'off'); % Create invisible figure

        % Loop through each condition for this subject
        for j = 1:numConds
            condition = condList{j};

            % Compute weighted average and convert to µV
            data = AverageData(condition, weightedStruct) * 1e6;
            GFP = std(data);  % Global Field Power

            subplot(subplotRows, subplotCols, j);
            hold on;
            plot(ts, data, 'b', 'LineWidth', 0.1); % Channel data
            plot(ts, GFP, 'r', 'LineWidth', 2);    % GFP
            xlabel('Time (s)');
            ylabel('Amplitude (µV)');
            title(condition);
            grid on;
            xlim([0, 0.75]);
        end

        % Add a title for the full figure
        sgtitle([subplotTitle, ' - ', strrep(files(i).name, '_', '\_')]);

        % Save the figure to file
        saveName = [files(i).name(1:end-4), '_EEGPlot.png']; % Remove .mat extension
        savePath = fullfile(outputDir, saveName);
        exportgraphics(fig, savePath); % Save figure
        close(fig); % Close figure to free memory
    end

    % Nested function to compute weighted average of all triggers in one condition
    function avgData = AverageData(cond, struct)
        triggerNames = fieldnames(struct.(cond));
        summedData = zeros(63, 1051);
        summedWeight = 0;

        for k = 1:length(triggerNames)
            dataStruct = struct.(cond).(triggerNames{k});

            if isfield(dataStruct, 'num_files')
                dataWeight = dataStruct.num_files;
            elseif isfield(dataStruct, 'num_files_trigger')
                dataWeight = dataStruct.num_files_trigger;
            end

            if isfield(dataStruct, 'epoch_avg')
                dataMatrix = dataStruct.epoch_avg;
            elseif isfield(dataStruct, 'epoch_avg_trigger')
                dataMatrix = dataStruct.epoch_avg_trigger;
            end 

            summedData = summedData + dataMatrix * dataWeight;
            summedWeight = summedWeight + dataWeight;
        end

        avgData = summedData / summedWeight;
    end
end
