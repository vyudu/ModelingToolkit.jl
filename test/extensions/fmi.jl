using ModelingToolkit, FMI, FMIZoo, OrdinaryDiffEq
using ModelingToolkit: t_nounits as t, D_nounits as D
import ModelingToolkit as MTK

@testset "Standalone pendulum model" begin
    fmu = loadFMU("SpringPendulum1D", "Dymola", "2022x"; type = :ME)
    truesol = FMI.simulate(
        fmu, (0.0, 8.0); saveat = 0.0:0.1:8.0, recordValues = ["mass.s", "mass.v"])

    @testset "v2, ME" begin
        fmu = loadFMU("SpringPendulum1D", "Dymola", "2022x"; type = :ME)
        @mtkbuild sys = MTK.FMIComponent(Val(2); fmu, type = :ME)
        prob = ODEProblem{true, SciMLBase.FullSpecialize}(
            sys, [sys.mass__s => 0.5, sys.mass__v => 0.0], (0.0, 8.0))
        sol = solve(prob, Tsit5(); reltol = 1e-8, abstol = 1e-8)
        @test SciMLBase.successful_retcode(sol)

        @test sol(0.0:0.1:8.0;
            idxs = [sys.mass__s, sys.mass__v]).u≈collect.(truesol.values.saveval) atol=1e-4
        # repeated solve works
        @test_nowarn solve(prob, Tsit5())
    end
    @testset "v2, CS" begin
        fmu = loadFMU("SpringPendulum1D", "Dymola", "2022x"; type = :CS)
        @named inner = MTK.FMIComponent(
            Val(2); fmu, communication_step_size = 0.001, type = :CS)
        @variables x(t) = 1.0
        @mtkbuild sys = ODESystem([D(x) ~ x], t; systems = [inner])

        prob = ODEProblem{true, SciMLBase.FullSpecialize}(
            sys, [sys.inner.mass__s => 0.5, sys.inner.mass__v => 0.0], (0.0, 8.0))
        sol = solve(prob, Tsit5(); reltol = 1e-8, abstol = 1e-8)
        @test SciMLBase.successful_retcode(sol)

        @test sol(0.0:0.1:8.0;
            idxs = [sys.inner.mass__s, sys.inner.mass__v]).u≈collect.(truesol.values.saveval) rtol=1e-2
    end
end

@testset "IO Model" begin
    @testset "v2, ME" begin
        fmu = loadFMU("../../omc-fmus/SimpleAdder.fmu"; type = :ME)
        @named adder = MTK.FMIComponent(Val(2); fmu, type = :ME)
        @variables a(t) b(t) c(t) [guess = 1.0]
        @mtkbuild sys = ODESystem(
            [adder.a ~ a, adder.b ~ b, D(a) ~ t,
                D(b) ~ adder.out + adder.c, c^2 ~ adder.out + adder.value],
            t;
            systems = [adder])

        # c will be solved for by initialization
        # this tests that initialization also works with FMUs
        prob = ODEProblem(sys, [sys.adder.c => 1.0, sys.a => 1.0, sys.b => 1.0], (0.0, 1.0))
        sol = solve(prob, Rodas5P(autodiff = false))
        @test SciMLBase.successful_retcode(sol)
    end
    @testset "v2, CS" begin
        fmu = loadFMU("../../omc-fmus/SimpleAdder.fmu"; type = :CS)
        @named adder = MTK.FMIComponent(
            Val(2); fmu, type = :CS, communication_step_size = 0.001)
        @variables a(t) b(t) c(t) [guess = 1.0]
        @mtkbuild sys = ODESystem(
            [adder.a ~ a, adder.b ~ b, D(a) ~ t,
                D(b) ~ adder.out + adder.c, c^2 ~ adder.out + adder.value],
            t;
            systems = [adder])

        # c will be solved for by initialization
        # this tests that initialization also works with FMUs
        prob = ODEProblem(sys, [sys.adder.c => 1.0, sys.a => 1.0, sys.b => 1.0],
            (0.0, 1.0); use_scc = false)
        sol = solve(prob, Rodas5P(autodiff = false))
        @test SciMLBase.successful_retcode(sol)
    end
end
