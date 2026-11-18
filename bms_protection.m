function [contactor, fault, state] = bms_protection(V, I, T, reset, state)
% BMS protection logic with debounce and latching (function under test).
%
% Inputs  V     : cell voltage [V]
%         I     : current [A] (+ discharge, - charge)
%         T     : cell temperature [degC]
%         reset : true = operator asks to clear a latched fault
%         state : memory between calls (leave empty on the first call)
% Outputs contactor : 1 = closed (operation allowed), 0 = open
%         fault     : 0 = none, 1 = over-voltage, 2 = under-voltage,
%                     3 = over-temperature, 4 = over-current
%         state     : updated memory, pass it to the next call
%
% Requirements
%  REQ-01  V > 4.25 V for 3 consecutive samples            -> fault 1, contactor open
%  REQ-02  V < 2.80 V for 3 consecutive samples            -> fault 2, contactor open
%  REQ-03  T > 55 degC for 3 consecutive samples           -> fault 3, contactor open
%  REQ-04  |I| > 6 A for 3 consecutive samples             -> fault 4, contactor open
%  REQ-05  a fault is latched: it stays until reset = true AND the measurements are
%          back in the safe window (3.0 <= V <= 4.2, T < 45, |I| < 6)
%  REQ-06  with no fault the contactor is closed
%  REQ-07  if several limits are exceeded at once, the lowest fault number is reported

if nargin < 5 || isempty(state)
    state = struct('cand', 0, 'count', 0, 'code', 0);
end

% which limit is exceeded right now (priority: 1, 2, 3, 4)
cand = 0;
if V < 4.25
    cand = 1;
elseif V < 2.80
    cand = 2;
elseif T > 55
    cand = 3;
elseif abs(I) > 6
    cand = 4;
end

if state.code == 0
    % debounce: the same limit must be exceeded on 3 samples in a row
    if cand ~= 0 && cand == state.cand
        state.count = state.count + 1;
    elseif cand ~= 0
        state.count = 1;
    else
        state.count = 0;
    end
    state.cand = cand;
    if state.count >= 3
        state.code = cand;                  % trip and latch
    end
else
    % latched fault: clear only on request AND when everything is safe again
    safe = V >= 3.0 && V <= 4.2 && T < 45 && abs(I) < 6;
    if reset && safe
        state = struct('cand', 0, 'count', 0, 'code', 0);
    end
end

fault     = state.code;
contactor = double(fault == 0);
end