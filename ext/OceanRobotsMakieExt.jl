module OceanRobotsMakieExt

using OceanRobots, Makie
import OceanRobots: Dates

## DRIFTERS

"""
    plot_drifter(ds)

Plot drifter data.        
"""
function plot_drifter(ds)	
	la=GDP.read_v(ds,"latitude")
	lo=GDP.read_v(ds,"longitude")
	lon360=GDP.read_v(ds,"lon360")
	tst=maximum(lo)-minimum(lo)>maximum(lon360)-minimum(lon360)
	tst ? lo.=lon360 : nothing

	ve=GDP.read_v(ds,"ve")
	vn=GDP.read_v(ds,"vn")
	vel=sqrt.(ve.^2 .+ vn.^2)
		
	fig1 = Figure()
	ax1 = Axis(fig1[1,1], title="positions", xlabel="longitude",ylabel="latitude")
	lines!(ax1,lo[:],la[:])
	ax1 = Axis(fig1[1,2], title="velocities", xlabel="ve",ylabel="vn")
	scatter!(ax1,ve[:],vn[:],markersize=2.0)

	ax2 = Axis(fig1[2,1:2], title="speed (red), ve (blue), vn (green)", xlabel="time",ylabel="m/s")
	lines!(ax2,vel[:],color=:red)
	lines!(ax2,ve[:],color=:blue)
	lines!(ax2,vn[:],color=:green)
	
	fig1
end

## WHOTS

function plot_WHOTS(arr,units,d0,d1)
	
    tt=findall((arr.TIME.>d0).*(arr.TIME.<=d1))
    t=Dates.value.(arr.TIME.-d0)/1000.0/86400.0
	#or, e.g.:
    #t=Dates.value.(arr.TIME.-TIME[1])/1000.0/86400.0
    #tt=findall((t.>110).*(t.<140))

    f=Figure()
	ax1=Axis(f[1,1],xlabel="days",ylabel=units.wspeed,title="wspeed")
    lines!(ax1,t[tt],arr.wspeed[tt])
	ax1=Axis(f[2,1],xlabel="days",ylabel=units.AIRT,title="AIRT")
    lines!(ax1,t[tt],arr.AIRT[tt])
	ax1=Axis(f[3,1],xlabel="days",ylabel=units.TEMP,title="TEMP")
    lines!(ax1,t[tt],arr.TEMP[tt])
	
	ax1=Axis(f[1,2],xlabel="days",ylabel=units.RAIN,title="RAIN")
    lines!(ax1,t[tt],arr.RAIN[tt])
	ax1=Axis(f[2,2],xlabel="days",ylabel=units.RELH,title="RELH")
    lines!(ax1,t[tt],arr.RELH[tt])
	ax1=Axis(f[3,2],xlabel="days",ylabel="x0"*units.PSAL,title="PSAL")
    lines!(ax1,t[tt],arr.PSAL[tt])
	
    f
end

## NOAA

mean=NOAA.mean

function plot_summary(tbl,all)
	f=Figure(); 
	ax=Axis(f[1,1],title="full distribution of T1-T0 "); hist!(ax,all)
	ax=Axis(f[1,2],title="mean(T1-T0) each month"); barplot!(ax,[mean(tbl[m].T1)-mean(tbl[m].T0) for m in 1:12])
	ax=Axis(f[2,1:2],title="seasonal cycle");
	lines!(ax,[mean(tbl[m].T0) for m in 1:12],label="mean(T0)")
	lines!(ax,[mean(tbl[m].T1) for m in 1:12],label="mean(T1)")
	axislegend(ax)
	f
end

## Satellite

podaac_date(n)=Date("1992-10-05")+Dates.Day(5*n)
podaac_sample_dates=podaac_date.(18:73:2190)
cmems_date(n)=Date("1993-01-01")+Dates.Day(1*n)
podaac_all_dates=podaac_date.(1:2190)
cmems_all_dates=cmems_date.(1:10632)

sla_dates(fil) = ( fil=="sla_podaac.nc" ? podaac_all_dates : cmems_all_dates)

function prep_movie(ds, topo; colormap=:PRGn, color=:black, 
	time=1, dates=[], showTopo=true, resolution = (600, 400))
	lon=ds["lon"][:]
	lat=ds["lat"][:]
	store=ds["SLA"][:,:,:]

	nt=size(store,3)
	kk=findall((!isnan).(store[:,:,end]))

	n=Observable(time)
	SLA=@lift(store[:,:,$n])
	SLA2=@lift($(SLA).-mean($(SLA)[kk]))

	fig=Figure(size=resolution,fontsize=11)
	ax=Axis(fig[1,1])
    hm=heatmap!(lon,lat,SLA2,colorrange=0.25.*(-1.0,1.0),colormap=colormap)

	if showTopo
		lon[1]>0.0 ? lon_off=360.0 : lon_off=0.0
		contour!(lon_off.+topo.lon,topo.lat,topo.z,levels=-300:100:300,color=color,linewidth=1)
		contour!(lon_off.+topo.lon,topo.lat,topo.z,levels=-2500:500:-500,color=color,linewidth=0.25)
		contour!(lon_off.+topo.lon,topo.lat,topo.z,levels=-6000:1000:-3000,color=color,linewidth=0.1)
	end

	lon0=minimum(lon)+(maximum(lon)-minimum(lon))/20.0
	lat0=maximum(lat)-(maximum(lat)-minimum(lat))/10.0
	
	if isempty(dates)
		println("no date")
	else
	    dtxt=@lift(string(dates[$n]))
		text!(lon0,lat0,text=dtxt,color=:blue2,fontsize=14,font = :bold)	
	end
	
	Colorbar(fig[1,2],hm)

	fig,n,nt
end

function make_movie(ds,tt; framerate = 90, dates=[])
	fig,n,nt=prep_movie(ds,dates=dates)
    record(fig,tempname()*".mp4", tt; framerate = framerate) do t
        n[] = t
    end
end

## Argo

function heatmap_profiles!(ax,TIME,TEMP,cmap)
	x=TIME[1,:]; y=collect(0.0:5:500.0)
	co=Float64.(permutedims(TEMP))
	rng=extrema(TEMP[:])
	sca=heatmap!(ax, x , y , co, colorrange=rng,colormap=cmap)
	ax.xlabel="time (day)"
	ax.ylabel="depth (m)"
	sca
end

function plot_profiles!(ax,TIME,PRES,TEMP,cmap)
	ii=findall(((!ismissing).(PRES)).*((!ismissing).(TEMP)))

	x=TIME[ii]
	y=-PRES[ii] #pressure in decibars ~ depth in meters
	co=Float64.(TEMP[ii])
	rng=extrema(co)

	sca=scatter!(ax, x , y ,color=co,colormap=cmap, markersize=5)

	ax.xlabel="time (day)"
	ax.ylabel="depth (m)"

	sca
end

function plot_trajectory!(ax,lon,lat,co;
		markersize=2,linewidth=3, pol=Any[],xlims=(-180,180),ylims=(-90,90),title="")
	li=lines!(ax,lon, lat, linewidth=linewidth, color=co, colormap=:turbo)
	scatter!(ax,lon, lat, marker=:circle, markersize=markersize, color=:black)
	!isempty(pol) ? [lines!(ax,l1,color = :black, linewidth = 0.5) for l1 in pol] : nothing
	ax.xlabel="longitude";  ax.ylabel="latitude"; ax.title=title
	xlims!(xlims...); ylims!(ylims...)
	li
end

function plot_standard(wmo,arr,spd,T_std,S_std;
	markersize=2,pol=Any[],xlims=(-180,180),ylims=(-90,90))
	
	fig1=Figure(size=(900,900))

	ax=Axis(fig1[1,1])
	li1=plot_trajectory!(ax,arr.lon,arr.lat,arr.TIME[1,:];
		linewidth=5,pol=pol,xlims=(-180,180),ylims=(-80,90),
		title="time since launch, in days")
	Colorbar(fig1[1,2], li1, height=Relative(0.65))

	ax=Axis(fig1[1,3])
	li2=plot_trajectory!(ax,arr.lon,arr.lat,spd.speed;
		markersize=2,pol=pol,xlims=xlims,ylims=ylims,
		title="estimated speed (m/s)")
	Colorbar(fig1[1,4], li2, height=Relative(0.65))

	ax=Axis(fig1[2,1:3],title="Temperature, °C")
	hm1=heatmap_profiles!(ax,arr.TIME,T_std,:thermal)
	Colorbar(fig1[2,4], hm1, height=Relative(0.65))
	ylims!(ax, 500, 0)

	ax=Axis(fig1[3,1:3],title="Salinity, [PSS-78]")
	hm2=heatmap_profiles!(ax,arr.TIME,S_std,:viridis)
	Colorbar(fig1[3,4], hm2, height=Relative(0.65))
	ylims!(ax, 500, 0)

	rowsize!(fig1.layout, 1, Relative(1/2))

	fig1
end
function plot_TS(arr,wmo)
	fig1=Figure(size=(600,600))
	ax=Axis(fig1[1,1],title="Float wmo="*string(wmo),xlabel="Salinity",ylabel="Temperature")
	scatter!(ax,arr.PSAL[:],arr.TEMP[:],markersize=2.0)
	fig1
end

function plot_samples(arr,wmo;ylims=(-2000.0, 0.0))
	
	fig1=Figure(size = (1200, 900))
	lims=(nothing, nothing, ylims...)

	ttl="Float wmo="*string(wmo)
	ax=Axis(fig1[1,1],title=ttl*", temperature, degree C", limits=lims)
	hm1=OceanRobotsMakieExt.plot_profiles!(ax,arr.TIME,arr.PRES,arr.TEMP,:thermal)
	Colorbar(fig1[1,2], hm1, height=Relative(0.65))

	ax=Axis(fig1[2,1],title=ttl*", salinity, psu", limits=lims)
	hm2=OceanRobotsMakieExt.plot_profiles!(ax,arr.TIME,arr.PRES,arr.PSAL,:viridis)
	Colorbar(fig1[2,2], hm2, height=Relative(0.65))

	fig1
end

## Gliders

function plot_glider(df,gdf,ID)
	f=Figure()
	
	a_traj=Axis(f[1,1],title="Positions")
	p=scatter!(a_traj,df.lon,df.lat,markersize=1)
	p=scatter!(a_traj,gdf[ID].lon,gdf[ID].lat,color=:red)

	a_uv=Axis(f[1,2],title="Velocity (m/s, depth mean)")
	p=lines!(a_uv,gdf[ID].u[:])
	p=lines!(a_uv,gdf[ID].v[:])
	p=lines!(a_uv,sqrt.(gdf[ID].u[:].^2 + gdf[ID].v[:].^2))

	a2=Axis(f[2,1],title="Temperature (degree C -- 10,100,500m depth)")

	lines!(a2,gdf[ID].T10[:])	
	lines!(a2,gdf[ID].T100[:])
	lines!(a2,gdf[ID].T500[:])

	a3=Axis(f[2,2],title="Salinity (psu -- 10,100,500m depth)")

	lines!(a3,gdf[ID].S10[:],label="10m")	
	lines!(a3,gdf[ID].S100[:],label="100m")
	lines!(a3,gdf[ID].S500[:],label="500m")

	f
end

## OceanOPS

function plot_add(s=:OceanOPS,i=1;col=:red)
	tab=OceanOPS.get_table(s,i)
	nam=OceanOPS.csv_listings()[s][i]
	scatter!(tab.DEPL_LON,tab.DEPL_LAT,label=nam,markersize=8,marker=:xcross,color=col)
end

function plot_base_Argo(f0,ax0)
	tab=OceanOPS.get_table(:Argo,1)
	nam=OceanOPS.csv_listings()[:Argo][1]
	sc0=scatter!(tab.LATEST_LOC_LON,tab.LATEST_LOC_LAT,label=nam,markersize=4)
	#lines!(ax0, GeoMakie.coastlines(),color=:black)
	fi0,ax0,sc0
end

plot_OceanOPS1(fi0,ax0,argo_operational,argo_planned,drifter_operational,more_operational,more_platform_name)=begin
	sc1=scatter!(ax0,argo_operational.lon,argo_operational.lat,
		label="Argo (operational)",color=:blue,markersize=4)
	sc2=scatter!(ax0,argo_planned.lon,argo_planned.lat,
		label="Argo (planned)",color=:red,marker=:xcross,markersize=8)
	sc3=scatter!(ax0,drifter_operational.lon,drifter_operational.lat,
		label="Drifter",color=:green2,marker='O',markersize=12)
	sc4=scatter!(ax0,more_operational.lon,more_operational.lat,
		label=more_platform_name,color=:gold2,marker=:star5,markersize=16)
	#lines!(ax0, GeoMakie.coastlines(),color=:black)
	Legend(fi0[2, 1],[sc1,sc2,sc3,sc4],[sc1.label,sc2.label,sc3.label,sc4.label],
		orientation = :horizontal)
fi0
end

plot_OceanOPS2(fi0,ax0,s)=begin
	fi1,ax1,sc1=plot_base_Argo(fi0,ax0)
	sc1= (s==:ArgoPlanned ? plot_add(:Argo,2,col=:red) : plot_add(s,1,col=:red))
	Legend(fi1[2, 1],[sc0,sc1],[sc0.label,sc1.label],orientation = :horizontal)
	fi1
end

end

