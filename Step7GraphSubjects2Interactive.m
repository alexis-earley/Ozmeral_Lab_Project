function Step7GraphSubjects2Interactive(inputDir, outputDir, subplotTitle, maxTime, lowPass, highPass)
% Example:
%   Step7GraphSubjects2Interactive(inputDir, outputDir, 'Older Hearing Impaired (Unaided)', 2.0, 30, [])
% Input should be from Step6CNew

    % Defaults if not provided
    if nargin < 4 || isempty(maxTime),  maxTime  = 2.0; end
    if nargin < 5 || isempty(lowPass),  lowPass  = 30;  end   % default: low-pass only
    if nargin < 6,                      highPass = [];  end   % no high-pass by default

    % Create output directory if it doesn't exist
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    files = dir(fullfile(inputDir, '*.mat')); % Get subject files
    if isempty(files)
        error('No .mat files found in input directory.');
    end

    % Design filter (same rules as your non-interactive version)
    Fs  = 500; nyq = Fs/2;
    if ~isempty(highPass) && ~isempty(lowPass)
        assert(highPass > 0 && lowPass < nyq && highPass < lowPass, ...
            'Require 0 < highPass < lowPass < Fs/2.');
        [b,a] = butter(4, [highPass lowPass]/nyq, 'bandpass');
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
        weightedStruct = fileStruct.(varNames{1}); % ex. Subject_XXXX_6C

        % Automatically detect available conditions
        condList = sort(fieldnames(weightedStruct));

        numConds   = length(condList);
        subplotCols = 2;
        subplotRows = ceil(numConds / subplotCols);

        % Show the window so you can interact
        fig = figure('Visible', 'on', 'Position', [100, 100, 1400, 900]);

        % Loop through each condition for this subject
        for j = 1:numConds
            condition = condList{j};

            % Weighted average and convert to µV
            data = AverageData(condition, weightedStruct) * 1e6;   % 63 x T
            [rows, colsFull] = size(data);

            % Build full time axis (-0.1..2.0 s) and trim to maxTime
            tsFull    = linspace(-0.1, 2.0, colsFull);
            lastIndex = find(tsFull <= maxTime, 1, 'last');
            if isempty(lastIndex), lastIndex = colsFull; end
            ts   = tsFull(1:lastIndex);
            data = data(:, 1:lastIndex);

            % Filter each channel
            for ch = 1:rows
                if all(isfinite(data(ch, :)))
                    data(ch, :) = filtfilt(b, a, data(ch, :));
                end
            end

            GFP = std(data, 0, 1);  % Global Field Power

            subplot(subplotRows, subplotCols, j);
            hold on;

            % Draw channels and tag each line with its channel index
            hCh = plot(ts, data, 'LineWidth', 0.5);
            for ch = 1:rows
                set(hCh(ch), 'UserData', ch, 'PickableParts', 'all', 'HitTest', 'on');
            end

            % GFP line (tagged)
            hGFP = plot(ts, GFP, 'r', 'LineWidth', 2);
            set(hGFP, 'UserData', 'GFP', 'PickableParts', 'all', 'HitTest', 'on');

            xlabel('Time (s)');
            ylabel('Amplitude (\muV)');
            title(condition, 'Interpreter', 'none');
            grid on;
            xlim([-0.1, maxTime]);

            % Interactive datatips
            dcm = datacursormode(fig);
            set(dcm, 'Enable', 'on', 'UpdateFcn', @localChannelTip);
        end

        % Title for full figure
        sgtitle([subplotTitle, ' - ', strrep(files(i).name, '_', '\_')]);

        % Save the figure
        saveName = [files(i).name(1:end-4), '_EEGPlot.png'];
        savePath = fullfile(outputDir, saveName);
        exportgraphics(fig, savePath);

        if isgraphics(fig), uiwait(fig); end
        if isgraphics(fig), close(fig); end
    end

    % Weighted-average helper (unchanged)
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
            if k == 1
                [matrixRows, matrixCols] = size(dataMatrix);
                summedData   = zeros(matrixRows, matrixCols);
                summedWeight = 0;
            end
            summedData   = summedData   + dataMatrix .* dataWeight;
            summedWeight = summedWeight + dataWeight;
        end
        avgData = summedData ./ summedWeight;
    end
end

% datatip callback (unchanged)
function txt = localChannelTip(~, eventObj)
    hLine = get(eventObj, 'Target');
    ud = get(hLine, 'UserData');      % channel index or 'GFP'
    pos = get(eventObj, 'Position');  % [time, amplitude]
    if isnumeric(ud)
        chTxt = sprintf('Channel: %d', ud);
    else
        chTxt = sprintf('%s', ud);
    end
    txt = { chTxt, ...
            sprintf('Time: %.3f s', pos(1)), ...
            sprintf('Amp: %.2f \\muV', pos(2)) };
end
