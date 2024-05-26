module OceanRobots

using Dates
export DateTime, Date

import Base: read

include("types.jl")
include("thredds_servers.jl")
include("files.jl")
include("gridded_data.jl")

function check_for_file(set::String,args...)
    if set=="Glider_Spray"
        GliderFiles.check_for_file_Spray(args...)
    else
        println("unknown set")
    end
end

export GDP, GDP_CloudDrift, NOAA, GliderFiles, ArgoFiles, OceanSites, OceanOPS
export check_for_file, THREDDS, cmems_sla, podaac_sla

export NOAAbuoy, NOAAbuoy_monthly

read(x::NOAAbuoy,args...) = NOAA.read(args...)
read(x::NOAAbuoy_monthly,args...) = NOAA.read_monthly(args...)

end # module
