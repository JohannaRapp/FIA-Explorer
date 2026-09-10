function out = read_mzxml(filePath, scanIndices)
%READ_MZXML  Read an mzXML file.
%
%   OUT = READ_MZXML(FILEPATH) reads an mzXML file and returns a struct with
%   the fields READ_MZXML's callers need:
%
%       out.scan(k)      one entry per scan, has the scan attributes
%                        (num, msLevel, peaksCount, polarity, retentionTime,
%                        lowMz, highMz, basePeakMz, basePeakIntensity,
%                        totIonCurrent, ...) and
%       out.scan(k).peaks.mz
%                        the m/z-intensity pairs, interleaved in one
%                        vector: mz(1:2:end-1) are masses
%                        and mz(2:2:end) the matching intensities
%       out.mzXML.msRun.dataProcessing.software
%                        the conversion software that produced the file
%
%   OUT = READ_MZXML(FILEPATH, SCANINDICES) decodes the peak data only for
%   the listed scans. Attributes are still read for every scan, so
%   totIonCurrent remains available for the whole run. .
%
%
%   SUPPORTED
%
%       scan numbering    any; the num attribute is recorded, not validated
%       precision         32 (single) and 64 (double)
%       byteOrder         network (big-endian) and little
%       compressionType   none and zlib
%       mzXML version     2.x and 3.x
%
%
%   Part of the MATLAB app "FiaExplorer_V3.m".
%   Authors: Hannes Link, Johanna Rapp.

arguments
    filePath (1,:) char
    scanIndices double = []
end

if ~isfile(filePath)
    error('read_mzxml:fileNotFound', 'File not found: %s', filePath);
end

% Read the whole file as bytes. Keeping it as uint8 rather than char halves
% the memory (MATLAB char is two bytes per character) and lets STRFIND work
% on the raw bytes; only the small tag slices are ever converted to text.
fid = fopen(filePath, 'r');
if fid < 0
    error('read_mzxml:cannotOpen', 'Cannot open file: %s', filePath);
end
closeFile = onCleanup(@() fclose(fid));
data = fread(fid, inf, '*uint8').';

if isempty(strfind(data, uint8('<mzXML'))) && isempty(strfind(data, uint8('<msRun'))) %#ok<STREMP>
    error('read_mzxml:notMzXML', '%s is not an mzXML file.', filePath);
end

%% ------------------------------------------------------------------
%  Header: msRun and the conversion software
%  ------------------------------------------------------------------

out = struct('scan', [], 'mzXML', []);

msRunStart = strfind(data, uint8('<msRun'));
msRun = struct();
if ~isempty(msRunStart)
    msRun = parse_attributes(tag_text(data, msRunStart(1)));
end

% There are usually two <software> elements: the acquisition software inside
% <msInstrument>, and the conversion software inside <dataProcessing>. The
% conversion one is what identifies the MSConvert build, so search from
% <dataProcessing> forwards.
software = struct('type', [], 'name', [], 'version', []);
dataProcessingStart = strfind(data, uint8('<dataProcessing'));
if ~isempty(dataProcessingStart)
    softwareStart = strfind(data(dataProcessingStart(1):end), uint8('<software'));
    if ~isempty(softwareStart)
        software = parse_attributes( ...
            tag_text(data, dataProcessingStart(1) + softwareStart(1) - 1));
    end
end

msRun.dataProcessing = struct('software', software);
out.mzXML = struct('msRun', msRun);

%% ------------------------------------------------------------------
%  Locate the scans
%  ------------------------------------------------------------------

scanStart  = strfind(data, uint8('<scan '));
peaksStart = strfind(data, uint8('<peaks'));
peaksEnd   = strfind(data, uint8('</peaks>'));

nScans = numel(scanStart);

if nScans == 0
    error('read_mzxml:noScans', 'No scan elements found in %s.', filePath);
end

% This reader assumes one peaks element per scan, which is what MSConvert
% writes for MS1 data. Nested scans would break the pairing. This checks this:
if numel(peaksStart) ~= nScans || numel(peaksEnd) ~= nScans
    error('read_mzxml:unexpectedStructure', ...
        ['%s has %d scan elements but %d <peaks> and %d </peaks>. This ' ...
         'reader supports one peaks element per scan (MS1 data).'], ...
        filePath, nScans, numel(peaksStart), numel(peaksEnd));
end

if isempty(scanIndices)
    decodeThese = true(1, nScans);
else
    if any(scanIndices < 1) || any(scanIndices > nScans)
        error('read_mzxml:badScanIndices', ...
            'scanIndices must lie between 1 and %d for this file.', nScans);
    end
    decodeThese = false(1, nScans);
    decodeThese(scanIndices) = true;
end

isLittleEndianMachine = is_little_endian();

%% ------------------------------------------------------------------
%  Read each scan
%  ------------------------------------------------------------------

out.scan = repmat(empty_scan(), 1, nScans);

for k = 1:nScans
    scanAttributes = parse_attributes(tag_text(data, scanStart(k)));

    fieldNames = fieldnames(scanAttributes);
    for f = 1:numel(fieldNames)
        out.scan(k).(fieldNames{f}) = scanAttributes.(fieldNames{f});
    end

    % The peaks element belongs to this scan; its content runs from the end
    % of the opening tag to the matching closing tag.
    [peaksAttributeText, contentStart] = tag_text(data, peaksStart(k));
    peaksAttributes = parse_attributes(peaksAttributeText);

    out.scan(k).peaks = merge_into(empty_peaks(), peaksAttributes);

    if ~decodeThese(k)
        continue
    end

    encoded = data(contentStart:peaksEnd(k) - 1);
    out.scan(k).peaks.mz = decode_peaks(encoded, peaksAttributes, ...
        isLittleEndianMachine, filePath, k);

    % Cross-check against the count the converter recorded. A mismatch means
    % the decode went wrong
    expectedCount = 2 * out.scan(k).peaksCount;
    if ~isempty(out.scan(k).peaksCount) && numel(out.scan(k).peaks.mz) ~= expectedCount
        error('read_mzxml:peakCountMismatch', ...
            ['Scan %d of %s decoded to %d values but its peaksCount ' ...
             'attribute implies %d.'], ...
            k, filePath, numel(out.scan(k).peaks.mz), expectedCount);
    end
end

end

% =====================================================================
% Helpers
% =====================================================================

function [text, afterTag] = tag_text(data, tagStart)
%TAG_TEXT  Characters of the opening tag beginning at TAGSTART.
%
%   Returns the text from "<" up to and including the closing ">", and the
%   index of the first byte after it. Attribute values in mzXML are numbers,
%   simple names and ISO durations, none of which contain ">", so scanning
%   for the first ">" is sufficient.

searchWindow = data(tagStart:min(numel(data), tagStart + 8191));
closeAt = find(searchWindow == uint8('>'), 1);

if isempty(closeAt)
    error('read_mzxml:unterminatedTag', ...
        'An opening tag at byte %d is not terminated within 8 kB.', tagStart);
end

text = char(searchWindow(1:closeAt));
afterTag = tagStart + closeAt;

end

% ---------------------------------------------------------------------

function attributes = parse_attributes(tagText)
%PARSE_ATTRIBUTES  name="value" pairs of a tag, as a struct.
%
%   Values that parse as a number become double; everything else stays as a
%   character vector. 

attributes = struct();

tokens = regexp(tagText, '([A-Za-z_][\w:.-]*)\s*=\s*"([^"]*)"', 'tokens');

for k = 1:numel(tokens)
    name = matlab.lang.makeValidName(tokens{k}{1});
    rawValue = tokens{k}{2};

    numericValue = str2double(rawValue);
    if ~isnan(numericValue)
        attributes.(name) = numericValue;
    else
        attributes.(name) = rawValue;
    end
end

end

% ---------------------------------------------------------------------

function values = decode_peaks(encoded, peaksAttributes, isLittleEndianMachine, filePath, scanNumber)
%DECODE_PEAKS  base64 -> optional inflate -> typed numbers.

if isempty(encoded)
    values = [];
    return
end

bytes = decode_base64(encoded);

compression = get_field(peaksAttributes, 'compressionType', 'none');
switch lower(char(string(compression)))
    case {'none', ''}
        % nothing to do
    case 'zlib'
        bytes = inflate_zlib(bytes, filePath, scanNumber);
    otherwise
        error('read_mzxml:unsupportedCompression', ...
            ['Scan %d of %s uses compressionType "%s", which this reader ' ...
             'does not support. Re-convert with compression off, or with ' ...
             'zlib.'], scanNumber, filePath, char(string(compression)));
end

precision = get_field(peaksAttributes, 'precision', 32);
switch precision
    case 32
        values = typecast(bytes, 'single');
    case 64
        values = typecast(bytes, 'double');
    otherwise
        error('read_mzxml:unsupportedPrecision', ...
            'Scan %d of %s declares precision %g; expected 32 or 64.', ...
            scanNumber, filePath, precision);
end

% mzXML stores binary data in network (big-endian) order by default.
byteOrder = char(string(get_field(peaksAttributes, 'byteOrder', 'network')));
isBigEndianData = ~any(strcmpi(byteOrder, {'little', 'littleendian'}));

if isBigEndianData == isLittleEndianMachine
    values = swapbytes(values);
end

values = values(:);

end

% ---------------------------------------------------------------------

function bytes = decode_base64(encoded)
%DECODE_BASE64  Decode base64 bytes, preferring the fastest route available.
%
%   ENCODED is the raw uint8 slice of the document, not a char array; the
%   base64 alphabet is ASCII, so it can be reinterpreted as Java's signed
%   bytes with TYPECAST and handed straight over without a copy.
%
%   Java's decoder is roughly four times faster than MATLAB's on the ~9 MB
%   blob a single FIA scan produces, which is worth about five seconds per
%   file here. MATLAB's own decoder is kept as the fallback so that an
%   uncompressed file can still be read with no JVM.

% A pretty-printed document may wrap the base64 across lines, and both
% decoders reject embedded whitespace. Testing for it on the byte array is
% one cheap pass; actually stripping it costs far more, so only do that when
% there is something to strip. MSConvert writes the blob on one line.
if any(encoded < 33)
    encoded = encoded(encoded >= 33);
end

if usejava('jvm')
    try
        bytes = typecast( ...
            java.util.Base64.getDecoder().decode(typecast(encoded, 'int8')), 'uint8');
        return
    catch
        % fall through to the MATLAB decoder
    end
end

bytes = matlab.net.base64decode(char(encoded));

end

% ---------------------------------------------------------------------

function inflated = inflate_zlib(bytes, filePath, scanNumber)
%INFLATE_ZLIB 

if ~usejava('jvm')
    error('read_mzxml:noJvm', ...
        ['Scan %d of %s is zlib compressed, and decompressing needs the ' ...
         'JVM. Start MATLAB without -nojvm, or re-convert the file with ' ...
         '"Use zlib compression" switched off in MSConvert.'], ...
        scanNumber, filePath);
end

makeStream = @() java.util.zip.InflaterInputStream( ...
    java.io.ByteArrayInputStream(typecast(bytes, 'int8')));

% Which route works is a property of the JVM, and the JVM cannot change
% without restarting MATLAB, so decide once. Probing every scan would throw
% a few thousand Java exceptions over a full plate for no new information.
persistent hasReadAllBytes
if isempty(hasReadAllBytes)
    hasReadAllBytes = ismethod(makeStream(), 'readAllBytes');
end

% 1. Standard Java, from Java 9 onwards.
if hasReadAllBytes
    inflated = typecast(makeStream().readAllBytes(), 'uint8');
    return
end

% 2. Apache Commons IO, on the MATLAB Java class path.
try
    inflated = typecast( ...
        org.apache.commons.io.IOUtils.toByteArray(makeStream()), 'uint8');
    return
catch
    % fall through to the diagnosis below
end

error('read_mzxml:cannotInflate', ...
    ['Scan %d of %s is zlib compressed, but no usable Java decompressor ' ...
     'was found (Java %s).\nEither point MATLAB at a Java 9 or newer JDK ' ...
     'with jenv, or re-convert the file with "Use zlib compression" ' ...
     'switched off in MSConvert.'], ...
    scanNumber, filePath, string(version('-java')));

end

% ---------------------------------------------------------------------

function tf = is_little_endian()
%IS_LITTLE_ENDIAN  True on a little-endian machine (x86, Apple silicon).

[~, ~, endianness] = computer;
tf = strcmp(endianness, 'L');

end

% ---------------------------------------------------------------------

function value = get_field(structure, name, defaultValue)
%GET_FIELD  Field value, or a default when the attribute was absent.

if isfield(structure, name) && ~isempty(structure.(name))
    value = structure.(name);
else
    value = defaultValue;
end

end

% ---------------------------------------------------------------------

function target = merge_into(target, source)
%MERGE_INTO  Copy every field of SOURCE onto TARGET.

names = fieldnames(source);
for k = 1:numel(names)
    target.(names{k}) = source.(names{k});
end

end

% ---------------------------------------------------------------------

function s = empty_scan()
%EMPTY_SCAN  

s = struct( ...
    'num', [], 'msLevel', [], 'peaksCount', [], 'polarity', [], ...
    'scanType', [], 'centroided', [], 'deisotoped', [], ...
    'chargeDeconvoluted', [], 'retentionTime', [], 'ionisationEnergy', [], ...
    'collisionEnergy', [], 'collisionGas', [], 'collisionGasPressure', [], ...
    'startMz', [], 'endMz', [], 'lowMz', [], 'highMz', [], ...
    'basePeakMz', [], 'basePeakIntensity', [], 'totIonCurrent', [], ...
    'scanOrigin', struct(), 'precursorMz', struct(), 'maldi', [], ...
    'peaks', empty_peaks(), 'nameValue', struct(), 'comment', [], ...
    'msInstrumentID', []);

end

% ---------------------------------------------------------------------

function p = empty_peaks()
%EMPTY_PEAKS 

p = struct('precision', [], 'byteOrder', [], 'pairOrder', [], 'mz', [], ...
    'compressionType', [], 'compressedLen', [], 'contentType', []);

end
