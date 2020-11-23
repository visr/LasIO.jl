@info "Downloading LasTools"
import Pkg
if Sys.isapple()
    Pkg.add("LibGit2")
    using LibGit2
    resource_path = joinpath(dirname(@__DIR__), "resources")
    lastools_path = joinpath(dirname(@__DIR__), "LAStools")
    lastools_build_path = joinpath(lastools_path, "build")
    lastools_install_path = joinpath(lastools_build_path, "install")
    lastools_executable_path = joinpath(lastools_install_path, "bin")
    if !isdir(lastools_path)
        LibGit2.clone("https://github.com/LAStools/LAStools", lastools_path)
    end

    mkpath(lastools_build_path)
    cd(lastools_build_path)
    run(`cmake -DCMAKE_INSTALL_PREFIX=$(lastools_install_path) ../`)
    run(`cmake --build . --target install --config Release`)

    # find the las executable
    laszip_executables = filter(x -> startswith(x, "laszip"), readdir(lastools_executable_path))
    length(laszip_executables) == 0 && error("Unable to build a laszip executable for $(Sys.MACHINE)") 
    cp(joinpath(lastools_executable_path, laszip_executables[1]), joinpath(resource_path, "laszip"), force=true)
    rm(lastools_path, recursive=true)
end