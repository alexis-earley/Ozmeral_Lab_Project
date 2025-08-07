function Step7GraphSubjects2(inputDir, outputDir, subplotTitle)
% Example:
%   Step7GraphSubjects2(inputDir, outputDir,'Older Hearing Impaired (Unaided)')
% Input should be from Step6CNew

    % Create output directory if it doesn't exist
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    files = dir(fullfile(inputDir, '*.mat')); % Get subject files
    if isempty(files)
        error('No .mat files found in input directory.');
    end

    % Define 30 Hz low-pass filter
    Fs = 500;  % Sampling rate
    cutoff = 30;  
    [b, a] = butter(4, cutoff / (Fs / 2), 'low');

    for i = 1:length(files)
        filePath = fullfile(inputDir, files(i).name);
        disp(['Processing: ', files(i).name]);

        % Load subject struct
        fileStruct = load(filePath);
        varNames = fieldnames(fileStruct);
        weightedStruct = fileStruct.(varNames{1}); % ex. Subject_0604_6C

        % Automatically detect available conditions
        condList = sort(fieldnames(weightedStruct));

        numConds = length(condList);
        subplotCols = 2;
        subplotRows = ceil(numConds / subplotCols);
        fig = figure('Visible', 'off', 'Position', [100, 100, 1400, 900]); % Create invisible figure

        % Loop through each condition for this subject
        for j = 1:numConds
            condition = condList{j};

            % Compute weighted average and convert to µV
            data = AverageData(condition, weightedStruct) * 1e6;

            % Filter each channel
            for ch = 1:size(data, 1)
                if all(isfinite(data(ch, :)))
                    data(ch, :) = filtfilt(b, a, data(ch, :));
                end
            end

            GFP = std(data);  % Global Field Power

            subplot(subplotRows, subplotCols, j);
            hold on;

            [rows, cols] = size(data);

            ts = linspace(-0.1, 2.0, cols);  % Time vector (in seconds)
            plot(ts, data, 'b', 'LineWidth', 0.5); % Channel data
            plot(ts, GFP, 'r', 'LineWidth', 2);    % GFP
            xlabel('Time (s)');
            ylabel('Amplitude (µV)');
            title(condition);
            grid on;
            xlim([-0.1, 2]);
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

            if k== 1
                [matrixRows, matrixCols] = size(dataMatrix);
                summedData = zeros(matrixRows, matrixCols);
                summedWeight = 0;
            end

            summedData = summedData + dataMatrix .* dataWeight;
            summedWeight = summedWeight + dataWeight;
        end

        avgData = summedData ./ summedWeight;
    end
end
