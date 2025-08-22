function Step7GraphAll3Interactive(sourceDir, destFolder, subplotTitle, maxTime, lowPass, highPass)

    % Defaults for filters (like Step7GraphAll3)
    if nargin < 5 || isempty(lowPass),  lowPass  = 30; end
    if nargin < 6,                      highPass = []; end

    % Ensure output directory exists
    if ~exist(destFolder, 'dir')
        mkdir(destFolder);
    end

    % Get all .mat files from source directory
    files = dir(fullfile(sourceDir, '*.mat'));
    if isempty(files)
        error('No .mat files found in source directory.');
    end

    % Design filter safely
    Fs = 500;              % Sampling rate in Hz (≈1051 samples over ~2.1 s)
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

    for f = 1:length(files)
        filePath = fullfile(sourceDir, files(f).name);
        disp(['Processing: ', files(f).name]);

        % Load struct from file
        fileStruct = load(filePath);
        varNames = fieldnames(fileStruct);
        rootStruct = fileStruct.(varNames{1});

        % Support both: root.all_subjects.* or root *is already* all_subjects
        if isfield(rootStruct, 'all_subjects')
            weightedStruct = rootStruct.all_subjects;
        else
            weightedStruct = rootStruct;
        end

        % Setup for figure layout
        conditionList = sort(fieldnames(weightedStruct));
        numConds = length(conditionList);
        if numConds == 0
            warning('No conditions found under all_subjects in %s', files(f).name);
            continue;
        end

        % Infer time vector from first condition
        firstCond = weightedStruct.(conditionList{1});
        if ~isfield(firstCond, 'epoch_avg')
            warning('Missing epoch_avg in first condition of %s', files(f).name);
            continue;
        end
        [~, nT] = size(firstCond.epoch_avg);
        tsFull = linspace(-0.1, 2.0, nT);  % Time vector in seconds

        % Determine trimming index based on maxTime (seconds)
        if nargin >= 4 && ~isempty(maxTime)
            lastIndex = find(tsFull <= maxTime, 1, 'last');
            if isempty(lastIndex), lastIndex = nT; end
        else
            lastIndex = nT;
            maxTime   = tsFull(end); % for xlim below
        end
        ts = tsFull(1:lastIndex);

        subplotCols = 2;
        subplotRows = ceil(numConds / subplotCols);

        % Visible interactive figure (like Step7GraphAll2Interactive)
        fig = figure('Visible', 'on', 'Name', files(f).name, 'NumberTitle', 'off', ...
                     'Position', [100, 100, 1400, 900]);

        for i = 1:numConds
            condition = conditionList{i};
            condStruct = weightedStruct.(condition);

            if ~isfield(condStruct, 'epoch_avg')
                warning('Condition %s missing epoch_avg in %s — skipping.', condition, files(f).name);
                continue;
            end

            data = condStruct.epoch_avg(:, 1:lastIndex) * 1e6;  % µV, clipped to maxTime
            [rows, ~] = size(data);

            % Apply filter to each channel
            for ch = 1:rows
                if all(isfinite(data(ch, :)))
                    data(ch, :) = filtfilt(b, a, data(ch, :));
                else
                    warning('Non-finite values found in channel %d (%s), skipping filter.', ch, condition);
                end
            end

            GFP = std(data, 0, 1);  % Global Field Power

            subplot(subplotRows, subplotCols, i);
            hold on;

            % --- Draw all channels and tag each line with its channel index ---
            hCh = plot(ts, data, 'LineWidth', 0.5);     % 63 lines, one per row/channel
            for ch = 1:rows
                set(hCh(ch), 'UserData', ch, 'PickableParts', 'all', 'HitTest', 'on');
            end

            % GFP line
            hGFP = plot(ts, GFP, 'LineWidth', 2);
            set(hGFP, 'UserData', 'GFP', 'PickableParts', 'all', 'HitTest', 'on');

            xlabel('Time (s)');
            ylabel('Amplitude (\muV)');
            title(condition, 'Interpreter', 'none');
            grid on;
            xlim([-0.1, maxTime]);
            ylim([-3, 3]);

            % --- Enable interactive datatips showing the channel number ---
            dcm = datacursormode(gcf);  % or datacursormode(fig)
            set(dcm, 'Enable', 'on', 'UpdateFcn', @localChannelTip);
        end

        if numConds > 1
            titleAll = [subplotTitle, ' Average Potentials - ', files(f).name];
            sgtitle(titleAll, 'Interpreter', 'none', 'FontSize', 10);
        end

        % Save figure using base name from input file, appending index if needed
        [~, baseName, ~] = fileparts(files(f).name);
        saveBase = fullfile(destFolder, [baseName, '_AllConditions.png']);
        savePath = saveBase;
        suffix = 1;
        while isfile(savePath)
            savePath = fullfile(destFolder, [baseName, '_AllConditions_', num2str(suffix), '.png']);
            suffix = suffix + 1;
        end

        exportgraphics(fig, savePath);

        % Let you interact; if user closes the window, fig is gone
        if isgraphics(fig), uiwait(fig); end
        if isgraphics(fig), close(fig); end

        disp(['Saved figure to: ', savePath]);
    end

    disp('All figures processed.');
end

function txt = localChannelTip(~, eventObj)
    % eventObj.Target is the clicked line
    hLine = get(eventObj, 'Target');
    ud = get(hLine, 'UserData');      % channel index we stored, or 'GFP'
    pos = get(eventObj, 'Position');  % [time, amplitude]

    if isnumeric(ud)
        chTxt = sprintf('Channel: %d', ud);
    else
        chTxt = sprintf('%s', ud);    % e.g., 'GFP'
    end

    txt = { chTxt, ...
            sprintf('Time: %.3f s', pos(1)), ...
            sprintf('Amp: %.2f \\muV', pos(2)) };
end
