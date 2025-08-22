function s = SafeFile(x)
% Replace anything not alnum, dash, underscore, or dot with hyphen for filenames
s = regexprep(x, '[^A-Za-z0-9._-]', '-');
end
