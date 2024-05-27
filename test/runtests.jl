using OceanRobots, DataFrames, ArgoData, CairoMakie
using Test

@testset "OceanRobots.jl" begin

    url="https://dods.ndbc.noaa.gov/thredds/catalog/oceansites/long_timeseries/WHOTS/catalog.xml"
    files,folders=OceanRobots.THREDDS.parse_catalog(url)

    @test isa(files[1],String)
    @test isempty(folders)

    lst=GDP.list_files()
    b=read(SurfaceDrifter(),1,list_files=lst)
    @test haskey(b.data,"ve")

    f3=plot(b)
    @test isa(f3,Figure)

    #

    b=read(CloudDrift(),"")
    @test isa(b,CloudDrift)

    #

    oceansites_index=OceanSites.index()
    @test !isempty(oceansites_index)

    b=read(OceanSite(),:WHOTS)
    f3=plot(b,DateTime(2005,1,1),DateTime(2005,2,1))
    @test isa(f3,Figure)

    file="DATA_GRIDDED/WHOTS/OS_WHOTS_200408-201809_D_MLTS-1H.nc"
    data=OceanSites.read_variables(file,:lon,:lat,:time,:TEMP)
    @test !isempty(data.TEMP)

    #

    ArgoFiles.scan_txt("ar_index_global_prof.txt",do_write=true)
    @test isfile(joinpath(tempdir(),"ar_index_global_prof.csv"))

    ArgoFiles.scan_txt("argo_synthetic-profile_index.txt",do_write=true)
    @test isfile(joinpath(tempdir(),"argo_synthetic-profile_index.csv"))

    wmo=2900668
    files_list=GDAC.files_list()

    fil=ArgoFiles.download(files_list,wmo)
    arr=ArgoFiles.readfile(fil)
    b=ArgoFloat(wmo,arr)
    @test isa(b,ArgoFloat)

    f1=plot(b,option=:samples)
    f2=plot(b,option=:TS)
    f3=plot(b,option=:standard)
    @test isa(f3,Figure)
        
    #

    b=read(Gliders(),"GulfStream.nc")
    @test isa(b,Gliders)
    f3=plot(b,1)
    @test isa(f3,Figure)

    ##

    stations=[41046, 44065]		
	NOAA.download(stations)
    b=read(NOAAbuoy(),41046)
    plot(b,"PRES")
    @test isa(b,NOAAbuoy)

    ##

    buoyID=44013
    years=1985:1986

    NOAA.download_historical_txt(buoyID,years)
    df=NOAA.read_historical_txt(buoyID,years[1])
    @test isa(df,DataFrame)

    b=read(NOAAbuoy_monthly(),buoyID,years)
    @test isa(b,NOAAbuoy_monthly)

    a=read(NOAAbuoy_monthly(),44013)
    b=plot(a;option=:demo)
    @test isa(b,Figure)

    files_year,files_url=OceanRobots.THREDDS.parse_catalog_NOAA_buoy()
    @test !isempty(files_url)

    ##

    list_Argo=OceanOPS.get_list(:Argo)
    @test isa(list_Argo,Vector)

    tmp=OceanOPS.get_platform(list_Argo[1000])
    @test tmp.status=="OPERATIONAL"

    tmp=OceanOPS.get_list_pos(:Drifter)
    @test isa(tmp.lon,Vector)

    tmp=OceanOPS.list_platform_types()
    @test isa(tmp.name,Vector)

    ##

    b=read(SeaLevelAnomaly(),:sla_podaac)
    f3=plot(b)
    @test isa(f3,Figure)

end
