function Step7GraphSubjects2(inputDir, outputDir, subplotTitle, maxTime, lowPass, highPass)
% Example:
%   Step7GraphSubjects2(inputDir, outputDir,'Older Hearing Impaired (Unaided)')
% Input should be from Step6CNew

    % Defaults
    if nargin < 4 || isempty(maxTime),  maxTime  = []; end
    if nargin < 5 || isempty(lowPass),  lowPass  = 30; end
    if nargin < 6,                      highPass = []; end

    % Create output directory if it doesn't exist
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    files = dir(fullfile(inputDir, '*.mat')); % Get subject files
    if isempty(files)
        error('No .mat files found in input directory.');
    end

    % Filter design (like your other Step 7 scripts)
    Fs = 500;  % Sampling rate
    nyq = Fs/2;
    if ~isempty(highPass) && ~isempty(lowPass)
        assert(highPass > 0 && lowPass < nyq && highPass < lowPass, ...
            'Require 0 < highPass < lowPass < Fs/2.');
        [b,a] = butter(4, [highPass, lowPass]/nyq, 'bandpass');
    elseif ~isempty(lowPass)
        assert(lowPass > 0 && lowPass < nyq, 'Require 0 < lowPass < Fs/2.');
        [b,a] = butter(4, lowPass/nyq, 'low');
    elseif ~isempty(highPass)
        assert(highPass > 0 && highPass < nyq, 'Require 0 < highPass < Fs/2.');
        [b,a] = butter(4, highPass/nyq, 'high');
    else
        b = 1; a = 1; % no filtering
    end

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

            % Time vector (based on data length)
            [rows, cols] = size(data);
            tsFull = linspace(-0.1, 2.0, cols);

            % Trim to maxTime if provided
            if ~isempty(maxTime)
                lastIndex = find(tsFull <= maxTime, 1, 'last');
                if isempty(lastIndex), lastIndex = cols; end
            else
                lastIndex = cols;
            end
            ts = tsFull(1:lastIndex);
            data = data(:, 1:lastIndex);

            % Filter each channel
            for ch = 1:size(data, 1)
                if all(isfinite(data(ch, :)))
                    data(ch, :) = filtfilt(b, a, data(ch, :));
                end
            end

            GFP = std(data);  % Global Field Power

            subplot(subplotRows, subplotCols, j);
            hold on;

            plot(ts, data, 'b', 'LineWidth', 0.5); % Channel data
            plot(ts, GFP, 'r', 'LineWidth', 2);    % GFP
            xlabel('Time (s)');
            ylabel('Amplitude (\muV)');
            title(condition);
            grid on;
            if isempty(maxTime)
                xlim([-0.1, 2]);
            else
                xlim([-0.1, ts(end)]);
            end
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
