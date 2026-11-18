classdef test_bms_protection < matlab.unittest.TestCase
    % Unit tests for bms_protection.m (MATLAB unit testing framework).
    % Run all tests:   results = runtests('test_bms_protection');
    % Show a summary:  table(results)
    % Each test names the requirement (REQ-xx) it checks.

    methods (Test)

        function nominalKeepsContactorClosed(tc)            % REQ-06
            [c, f] = runSeq(3.7*ones(1,10), 2, 25);
            tc.verifyEqual(c, ones(1,10));
            tc.verifyEqual(f, zeros(1,10));
        end

        function overVoltageTripsOnThirdSample(tc)          % REQ-01 (debounce)
            [c, f] = runSeq(4.3*ones(1,5), 2, 25);
            tc.verifyEqual(f, [0 0 1 1 1]);
            tc.verifyEqual(c, [1 1 0 0 0]);
        end

        function singleGlitchDoesNotTrip(tc)                % REQ-01 (debounce)
            [~, f] = runSeq([3.7 4.3 3.7 4.3 3.7 3.7], 2, 25);
            tc.verifyEqual(f, zeros(1,6));
        end

        function valueExactlyAtLimitDoesNotTrip(tc)         % REQ-01 (boundary)
            [~, f] = runSeq(4.25*ones(1,6), 2, 25);
            tc.verifyEqual(f, zeros(1,6));
        end

        function valueJustAboveLimitTrips(tc)               % REQ-01 (boundary)
            [~, f] = runSeq(4.2501*ones(1,3), 2, 25);
            tc.verifyEqual(f(end), 1);
        end

        function underVoltageTrips(tc)                      % REQ-02
            [~, f] = runSeq(2.7*ones(1,3), 2, 25);
            tc.verifyEqual(f(end), 2);
        end

        function overTemperatureTrips(tc)                   % REQ-03
            [~, f] = runSeq(3.7*ones(1,3), 2, 60);
            tc.verifyEqual(f(end), 3);
        end

        function overCurrentDischargeTrips(tc)              % REQ-04
            [~, f] = runSeq(3.7*ones(1,3), 7, 25);
            tc.verifyEqual(f(end), 4);
        end

        function overCurrentChargeTrips(tc)                 % REQ-04 (negative current)
            [~, f] = runSeq(3.7*ones(1,3), -7, 25);
            tc.verifyEqual(f(end), 4);
        end

        function faultIsLatched(tc)                         % REQ-05
            [c, f] = runSeq([4.3*ones(1,3) 3.7*ones(1,5)], 2, 25);
            tc.verifyEqual(f(end), 1);
            tc.verifyEqual(c(end), 0);
            tc.verifyEqual(f(1:3), [0 0 1]);      % the fault must appear at sample 3, not later
        end

        function resetIsRefusedWhileUnsafe(tc)              % REQ-05
            V     = [4.3*ones(1,3) 3.7*ones(1,3)];
            T     = [25*ones(1,3)  60*ones(1,3)];            % still too hot
            reset = [false(1,3)    true(1,3)];
            [~, f] = runSeq(V, 2, T, reset);
            tc.verifyEqual(f(end), 1);
            tc.verifyEqual(f(3), 1);              % the fault must already be latched at sample 3
        end

        function resetClearsFaultWhenSafe(tc)               % REQ-05
            V     = [4.3*ones(1,3) 3.7*ones(1,3)];
            T     = [25*ones(1,3)  30*ones(1,3)];
            reset = [false(1,3)    true(1,3)];
            [c, f] = runSeq(V, 2, T, reset);
            tc.verifyEqual(f(end), 0);
            tc.verifyEqual(c(end), 1);
        end

        function lowestFaultNumberHasPriority(tc)           % REQ-07
            [~, f] = runSeq(4.3*ones(1,3), 2, 60);           % over-voltage and over-temperature
            tc.verifyEqual(f(end), 1);
        end

    end
end

%% Helper: feed a sequence of samples to the function under test
function [c, f] = runSeq(V, I, T, reset)
    n = max([numel(V) numel(I) numel(T)]);
    if numel(V) == 1, V = V*ones(1,n); end
    if numel(I) == 1, I = I*ones(1,n); end
    if numel(T) == 1, T = T*ones(1,n); end
    if nargin < 4, reset = false(1,n); end
    state = [];
    c = zeros(1,n);
    f = zeros(1,n);
    for k = 1:n
        [c(k), f(k), state] = bms_protection(V(k), I(k), T(k), reset(k), state);
    end
end