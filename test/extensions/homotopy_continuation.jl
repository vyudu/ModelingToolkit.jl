using ModelingToolkit, NonlinearSolve, SymbolicIndexingInterface
using LinearAlgebra
using Test
import HomotopyContinuation

@testset "No parameters" begin
    @variables x y z
    eqs = [0 ~ x^2 + y^2 + 2x * y
           0 ~ x^2 + 4x + 4
           0 ~ y * z + 4x^2]
    @mtkbuild sys = NonlinearSystem(eqs)
    prob = HomotopyContinuationProblem(sys, [x => 1.0, y => 1.0, z => 1.0], [])
    @test prob[x] == prob[y] == prob[z] == 1.0
    @test prob[x + y] == 2.0
    sol = solve(prob; threading = false)
    @test SciMLBase.successful_retcode(sol)
    @test norm(sol.resid)≈0.0 atol=1e-10
end

struct Wrapper
    x::Matrix{Float64}
end

@testset "Parameters" begin
    wrapper(w::Wrapper) = det(w.x)
    @register_symbolic wrapper(w::Wrapper)

    @variables x y z
    @parameters p q::Int r::Wrapper

    eqs = [0 ~ x^2 + y^2 + p * x * y
           0 ~ x^2 + 4x + q
           0 ~ y * z + 4x^2 + wrapper(r)]

    @mtkbuild sys = NonlinearSystem(eqs)
    prob = HomotopyContinuationProblem(sys, [x => 1.0, y => 1.0, z => 1.0],
        [p => 2.0, q => 4, r => Wrapper([1.0 1.0; 0.0 0.0])])
    @test prob.ps[p] == 2.0
    @test prob.ps[q] == 4
    @test prob.ps[r].x == [1.0 1.0; 0.0 0.0]
    @test prob.ps[p * q] == 8.0
    sol = solve(prob; threading = false)
    @test SciMLBase.successful_retcode(sol)
    @test norm(sol.resid)≈0.0 atol=1e-10
end

@testset "Array variables" begin
    @variables x[1:3]
    @parameters p[1:3]
    _x = collect(x)
    eqs = collect(0 .~ vec(sum(_x * _x'; dims = 2)) + collect(p))
    @mtkbuild sys = NonlinearSystem(eqs)
    prob = HomotopyContinuationProblem(sys, [x => ones(3)], [p => 1:3])
    @test prob[x] == ones(3)
    @test prob[p + x] == [2, 3, 4]
    prob[x] = 2ones(3)
    @test prob[x] == 2ones(3)
    prob.ps[p] = [2, 3, 4]
    @test prob.ps[p] == [2, 3, 4]
    sol = @test_nowarn solve(prob; threading = false)
    @test sol.retcode == ReturnCode.ConvergenceFailure
end

@testset "Parametric exponent" begin
    @variables x = 1.0
    @parameters n::Integer = 4
    @mtkbuild sys = NonlinearSystem([x^n + x^2 - 1 ~ 0])
    prob = HomotopyContinuationProblem(sys, [])
    sol = solve(prob; threading = false)
    @test SciMLBase.successful_retcode(sol)
end

@testset "Polynomial check and warnings" begin
    @variables x = 1.0
    @parameters n = 4
    @mtkbuild sys = NonlinearSystem([x^n + x^2 - 1 ~ 0])
    @test_warn ["Exponent", "not an integer", "@parameters"] @test_throws "not a polynomial" HomotopyContinuationProblem(
        sys, [])
    @mtkbuild sys = NonlinearSystem([x^1.5 + x^2 - 1 ~ 0])
    @test_warn ["Exponent", "not an integer"] @test_throws "not a polynomial" HomotopyContinuationProblem(
        sys, [])
    @mtkbuild sys = NonlinearSystem([x^x - x ~ 0])
    @test_warn ["Exponent", "unknowns"] @test_throws "not a polynomial" HomotopyContinuationProblem(
        sys, [])
    @mtkbuild sys = NonlinearSystem([((x^2) / sin(x))^2 + x ~ 0])
    @test_warn ["Unrecognized", "sin"] @test_throws "not a polynomial" HomotopyContinuationProblem(
        sys, [])
end

@testset "Rational functions" begin
    @variables x=2.0 y=2.0
    @parameters n = 4
    @mtkbuild sys = NonlinearSystem([
        0 ~ (x^2 - n * x + n) * (x - 1) / (x - 2) / (x - 3)
    ])
    prob = HomotopyContinuationProblem(sys, [])
    sol = solve(prob; threading = false)
    @test sol[x] ≈ 1.0
    p = parameter_values(prob)
    for invalid in [2.0, 3.0]
        @test prob.denominator([invalid], p)[1] <= 1e-8
    end

    @named sys = NonlinearSystem(
        [
            0 ~ (x - 2) / (x - 4) + ((x - 3) / (y - 7)) / ((x^2 - 4x + y) / (x - 2.5)),
            0 ~ ((y - 3) / (y - 4)) * (n / (y - 5)) + ((x - 1.5) / (x - 5.5))^2
        ],
        [x, y],
        [n])
    sys = complete(sys)
    prob = HomotopyContinuationProblem(sys, [])
    sol = solve(prob; threading = false)
    disallowed_x = [4, 5.5]
    disallowed_y = [7, 5, 4]
    @test all(!isapprox(sol[x]; atol = 1e-8), disallowed_x)
    @test all(!isapprox(sol[y]; atol = 1e-8), disallowed_y)
    @test sol[x^2 - 4x + y] >= 1e-8

    p = parameter_values(prob)
    for val in disallowed_x
        @test any(<=(1e-8), prob.denominator([val, 2.0], p))
    end
    for val in disallowed_y
        @test any(<=(1e-8), prob.denominator([2.0, val], p))
    end
    @test prob.denominator([2.0, 4.0], p)[1] <= 1e-8
end
