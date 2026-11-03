function mpc = build_5bus_case(fiveBus)
%BUILD_5BUS_CASE Construct the study's AMES-style MATPOWER DC-OPF case.
%   MPC = SEGAN.BUILD_5BUS_CASE(FIVEBUS) uses prepared raw inputs.
%   No stored simulation result or hard-coded computer path is required.

    define_constants;

    nBus = fiveBus.Meta.nBus;
    nGen = fiveBus.Meta.nGen;
    nBranch = fiveBus.Meta.nBranch;
    assert(nBus == 5 && nGen == 5 && nBranch == 6, ...
        'The five-bus input dimensions differ from the published design.');

    genBus = fiveBus.Generator.Bus(:);
    pmin = fiveBus.Generator.Pmin(:);
    pmax = fiveBus.Generator.Pmax(:);
    fromBus = fiveBus.Branch.From(:);
    toBus = fiveBus.Branch.To(:);

    mpc = struct();
    mpc.version = '2';
    mpc.baseMVA = 100;

    % MATPOWER bus columns are defined by define_constants.
    mpc.bus = zeros(nBus, 13);
    mpc.bus(:, BUS_I) = (1:nBus).';
    mpc.bus(:, BUS_TYPE) = PQ;
    mpc.bus(1, BUS_TYPE) = REF;
    mpc.bus(:, BUS_AREA) = 1;
    mpc.bus(:, VM) = 1;
    mpc.bus(:, BASE_KV) = 10;
    mpc.bus(:, ZONE) = 1;
    mpc.bus(:, VMAX) = 1.1;
    mpc.bus(:, VMIN) = 0.9;

    for g = 1:nGen
        if genBus(g) ~= 1
            mpc.bus(genBus(g), BUS_TYPE) = PV;
        end
    end

    % Generator cost coefficients are baseline (true) values in this case.
    mpc.gen = zeros(nGen, 21);
    mpc.gen(:, GEN_BUS) = genBus;
    mpc.gen(:, VG) = 1;
    mpc.gen(:, MBASE) = mpc.baseMVA;
    mpc.gen(:, GEN_STATUS) = 1;
    mpc.gen(:, PMAX) = pmax;
    mpc.gen(:, PMIN) = pmin;

    mpc.branch = zeros(nBranch, 13);
    mpc.branch(:, F_BUS) = fromBus;
    mpc.branch(:, T_BUS) = toBus;
    mpc.branch(:, BR_X) = fiveBus.Branch.X(:);
    mpc.branch(:, RATE_A) = fiveBus.Branch.RateA(:);
    mpc.branch(:, RATE_B) = fiveBus.Branch.RateB(:);
    mpc.branch(:, RATE_C) = fiveBus.Branch.RateC(:);
    mpc.branch(:, BR_STATUS) = 1;
    mpc.branch(:, ANGMIN) = -360;
    mpc.branch(:, ANGMAX) = 360;

    % MATPOWER polynomial cost: [MODEL STARTUP SHUTDOWN NCOST C2 C1 C0].
    % The published baseline cost is a * PG + b * PG^2.
    mpc.gencost = zeros(nGen, 7);
    mpc.gencost(:, 1) = 2;
    mpc.gencost(:, 4) = 3;
    mpc.gencost(:, 5) = fiveBus.TrueCost.b(:);
    mpc.gencost(:, 6) = fiveBus.TrueCost.a(:);

    assert(all(isfinite(mpc.gencost(:))) && ...
           all(mpc.gen(:, PMAX) >= mpc.gen(:, PMIN)), ...
           'Invalid five-bus MATPOWER generator inputs.');
end
