%function Step7CompareGroupsSE(dirList, dirNames, groupPairs, outputDir, maxTime)
function Step7CompareGroupsSE2(dirList, dirNames, groupPairs, outputDir, maxTime, lowPass, highPass)
    
    % NEW
    if nargin < 6, lowPass  = 30; end     % default low-pass at 30 Hz
    if nargin < 7, highPass = [];  end     % no high-pass by default

    % Create output directory if it doesn't exist
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    Fs = 500;  % Sampling rate in Hz
    totalSamples = 1051;  % Total samples in epoch
    timeVec = linspace(-0.1, 2.1 - 0.1, totalSamples); % Aka -0.1 to 2s
    lastIndex = find(timeVec <= maxTime, 1, 'last');  % Index of last sample <= maxTime
    ts = timeVec(1:lastIndex);  % Trimmed time vector

    % NEW - Filter (used ONLY for final visualization of grand-mean GFP)
    if ~isempty(lowPass) && ~isempty(highPass)
        if highPass <= 0 || lowPass <= 0 || highPass >= lowPass
            error('highPass must be > 0 and < lowPass.');
        end
        [b, a] = butter(4, [highPass, lowPass] / (Fs / 2), 'bandpass');
    elseif ~isempty(lowPass)
        if lowPass <= 0, error('lowPass must be > 0.'); end
        [b, a] = butter(4, lowPass / (Fs / 2), 'low');
    elseif ~isempty(highPass)
        if highPass <= 0, error('highPass must be > 0.'); end
        [b, a] = butter(4, highPass / (Fs / 2), 'high');
    else
        b = 1; a = 1;  % no filtering
    end

    allEEG = struct();  % Stores all EEG data organized by condition and group
    allConditions = {};  % Tracks unique condition names

    for g = 1:length(dirList)
        files = dir(fullfile(dirList{g}, '*.mat')); % Get all mat files in group folder
        for f = 1:length(files)
            S = load(fullfile(dirList{g}, files(f).name)); % Load EEG struct
            varName = fieldnames(S);
            subjStruct = S.(varName{1}); % Subject level
            condNames = fieldnames(subjStruct);
            allConditions = union(allConditions, condNames); % Add condition names list with all

            for c = 1:length(condNames)
                cond = condNames{c};
                eeg = subjStruct.(cond).epoch_avg(:, 1:lastIndex) * 1e6; % Clip to maxTime and convert to microvolts

                % Final-only filtering change: DO NOT filter channels here.
                % We keep each subject's EEG unfiltered for stats; we'll only filter the grand-mean GFP for display.

                % Add condition if first time
                if ~isfield(allEEG, cond)
                    allEEG.(cond) = cell(1, length(dirList));
                end
                % Append current EEG data to group’s list for this condition
                allEEG.(cond){g}(end+1, :, :) = eeg; %#ok<AGROW>
            end
        end
    end

    % Plot figure per condition
    condList = sort(allConditions); % Alphabetical condition order
    for c = 1:length(condList)
        cond = condList{c};
        fig = figure('Visible', 'off', 'Position', [100, 100, 1600, 900]);

        % For each group pair (e.g., [1 2], [3 4])
        for p = 1:size(groupPairs, 1)
            idx1 = groupPairs(p, 1);
            idx2 = groupPairs(p, 2);
            subplot(2, ceil(size(groupPairs, 1)/2), p); hold on;

            sigMask = false(1, lastIndex);  % Initialize time vector bool as all false

            for gIdx = [idx1, idx2] % Loop over first index in pair and then second one
                EEG = allEEG.(cond){gIdx}; % EEG data (subjects x channels x time)

                % Compute GFP per subject from UNFILTERED EEG (std across channels)
                subjGFPs = squeeze(std(EEG, 0, 2)); % subjects × time (unfiltered GFP per subject)

                % Subject-level mean and SE (still UNFILTERED)
                meanGFP_unfilt = mean(subjGFPs, 1);
                seGFP_unfilt   = std(subjGFPs, 0, 1) / sqrt(size(EEG, 1));

                % Final-only filtering: filter ONLY the grand-mean for plotting
                meanGFP_vis = filtfilt(b, a, meanGFP_unfilt); % visualization curve

                % Plot shaded SE area (around the UNFILTERED mean to keep stats honest)
                fill([ts fliplr(ts)], [meanGFP_unfilt+seGFP_unfilt fliplr(meanGFP_unfilt-seGFP_unfilt)], ...
                    'k', 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');

                % Plot filtered grand-mean GFP on top (visualization)
                plot(ts, meanGFP_vis, 'LineWidth', 2, 'DisplayName', dirNames{gIdx});
            end

            % Run two-sample t-tests between groups at each time point (UNFILTERED subj GFPs)
            gfp1 = squeeze(std(allEEG.(cond){idx1}, 0, 2)); % subjects × time (unfiltered)
            gfp2 = squeeze(std(allEEG.(cond){idx2}, 0, 2)); % same
            for t = 1:lastIndex
                [h, ~] = ttest2(gfp1(:, t), gfp2(:, t), 'Alpha', 0.05);  % t-test on unfiltered GFPs
                sigMask(t) = h;
            end

            % Mark significant timepoints with dots (visual guide)
            plot(ts(sigMask), -0.25 * ones(1, sum(sigMask)), 'k.', 'MarkerSize', 10);

            % Format subplot
            title([cond, ' - ', dirNames{idx1}, ' vs ', dirNames{idx2}]);
            xlabel('Time (s)');
            ylabel('GFP (µV)');
            xlim([-0.1, maxTime]);
            ylim([-0.5, 2]);
            grid on;
            legend('Location', 'northwest');
        end

        % Save full plot
        sgtitle(['GFP with SE: ', cond, ' (Final-only filtered mean)'], 'FontSize', 13);
        savePath = fullfile(outputDir, ['CompareGFP_', cond, '.png']);
        exportgraphics(fig, savePath);
        close(fig);
        disp(['Saved: ', savePath]);
    end
end
