#puts "#{__FILE__} checking in"
class Time
  SECS_IN_MIN=60
  SECS_IN_HOUR=SECS_IN_MIN*60
  SECS_IN_DAY=SECS_IN_HOUR*24
  SECS_IN_YEAR=SECS_IN_DAY*365 # screw leap years
  
  def self.timespan(t1,t0)
    t0=t0.to_i
    t1=t1.to_i
    d=(t1-t0).abs
    nYears=d/SECS_IN_YEAR
    d=d%SECS_IN_YEAR
    nDays=d/SECS_IN_DAY
    d=d%SECS_IN_DAY
    nHours=d/SECS_IN_HOUR
    d=d%SECS_IN_HOUR
    nMins=d/SECS_IN_MIN
    d=d%SECS_IN_MIN
    
    str=''
    str+="#{nYears} years " if nYears>0
    str+="#{nDays} days " if nDays>0
    str+="#{nHours} hours " if nHours>0
    str+="#{nMins} mins " if nMins>0
    str+="#{d.to_i} secs"
    str
  end

  def since(t0)
    Time.timespan(self,t0)
  end
end
