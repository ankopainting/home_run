# format.rb: Written by Tadayoshi Funaba 1999-2009
# $Id: format.rb,v 2.43 2008-01-17 20:16:31+09 tadf Exp $

class Date

  module Format # :nodoc:

    MONTHS = {
      'january'  => 1, 'february' => 2, 'march'    => 3, 'april'    => 4,
      'may'      => 5, 'june'     => 6, 'july'     => 7, 'august'   => 8,
      'september'=> 9, 'october'  =>10, 'november' =>11, 'december' =>12
    }

    DAYS = {
      'sunday'   => 0, 'monday'   => 1, 'tuesday'  => 2, 'wednesday'=> 3,
      'thursday' => 4, 'friday'   => 5, 'saturday' => 6
    }

    ABBR_MONTHS = {
      'jan'      => 1, 'feb'      => 2, 'mar'      => 3, 'apr'      => 4,
      'may'      => 5, 'jun'      => 6, 'jul'      => 7, 'aug'      => 8,
      'sep'      => 9, 'oct'      =>10, 'nov'      =>11, 'dec'      =>12
    }

    ABBR_DAYS = {
      'sun'      => 0, 'mon'      => 1, 'tue'      => 2, 'wed'      => 3,
      'thu'      => 4, 'fri'      => 5, 'sat'      => 6
    }

    [MONTHS, DAYS, ABBR_MONTHS, ABBR_DAYS].each do |x|
      x.freeze
    end

  end

  if RUBY_VERSION >= '1.9.0'
  def iso8601() strftime('%F') end

  def rfc3339() iso8601 end

  def xmlschema() iso8601 end # :nodoc:

  def rfc2822() strftime('%a, %d %b %Y %T %z') end

  alias_method :rfc822, :rfc2822

  def httpdate() new_offset(0).strftime('%a, %d %b %Y %T GMT') end # :nodoc:

  def jisx0301
    if jd < 2405160
      iso8601
    else
      case jd
      when 2405160...2419614
	g = 'M%02d' % (year - 1867)
      when 2419614...2424875
	g = 'T%02d' % (year - 1911)
      when 2424875...2447535
	g = 'S%02d' % (year - 1925)
      else
	g = 'H%02d' % (year - 1988)
      end
      g + strftime('.%m.%d')
    end
  end

  end

  def self.s3e(e, y, m, d, bc=false)
    unless String === m
      m = m.to_s
    end

    if y && m && !d
      y, m, d = d, y, m
    end

    if y == nil
      if d && d.size > 2
	y = d
	d = nil
      end
      if d && d[0,1] == "'"
	y = d
	d = nil
      end
    end

    if y
      y.scan(/(\d+)(.+)?/)
      if $2
	y, d = d, $1
      end
    end

    if m
      if m[0,1] == "'" || m.size > 2
	y, m, d = m, d, y # us -> be
      end
    end

    if d
      if d[0,1] == "'" || d.size > 2
	y, d = d, y
      end
    end

    if y
      y =~ /([-+])?(\d+)/
      if $1 || $2.size > 2
	c = false
      end
      iy = $&.to_i
      if bc
	iy = -iy + 1
      end
      e[:year] = iy
    end

    if m
      m =~ /\d+/
      e[:mon] = $&.to_i
    end

    if d
      d =~ /\d+/
      e[:mday] = $&.to_i
    end

    if c != nil
      e[:_][:comp] = c
    end

  end

  private_class_method :s3e

  def self._parse_day(str, e) # :nodoc:
    if str.sub!(/\b(#{Format::ABBR_DAYS.keys.join('|')})[^-\d\s]*/io, ' ')
      e[:wday] = Format::ABBR_DAYS[$1.downcase]
      true
    end
  end

  def self._parse_time(str, e) # :nodoc:
    if str.sub!(
		/(
		   (?:
		     \d+\s*:\s*\d+
		     (?:
		       \s*:\s*\d+(?:[,.]\d*)?
		     )?
		   |
		     \d+\s*h(?:\s*\d+m?(?:\s*\d+s?)?)?
		   )
		   (?:
		     \s*
		     [ap](?:m\b|\.m\.)
		   )?
		 |
		   \d+\s*[ap](?:m\b|\.m\.)
		 )
		 (?:
		   \s*
		   (
		     (?:gmt|utc?)?[-+]\d+(?:[,.:]\d+(?::\d+)?)?
		   |
		     [[:alpha:].\s]+(?:standard|daylight)\stime\b
		   |
		     [[:alpha:]]+(?:\sdst)?\b
		   )
		 )?
		/ix,
		' ')

      t = $1
      e[:zone] = $2 if $2

      t =~ /\A(\d+)h?
	      (?:\s*:?\s*(\d+)m?
		(?:
		  \s*:?\s*(\d+)(?:[,.](\d+))?s?
		)?
	      )?
	    (?:\s*([ap])(?:m\b|\.m\.))?/ix

      e[:hour] = $1.to_i
      e[:min] = $2.to_i if $2
      e[:sec] = $3.to_i if $3
      e[:sec_fraction] = Rational($4.to_i, 10**$4.size) if $4

      if $5
	e[:hour] %= 12
	if $5.downcase == 'p'
	  e[:hour] += 12
	end
      end
      true
    end
  end

  def self._parse_eu(str, e) # :nodoc:
    if str.sub!(
		/'?(\d+)[^-\d\s]*
		 \s*
		 (#{Format::ABBR_MONTHS.keys.join('|')})[^-\d\s']*
		 (?:
		   \s*
		   (c(?:e|\.e\.)|b(?:ce|\.c\.e\.)|a(?:d|\.d\.)|b(?:c|\.c\.))?
		   \s*
		   ('?-?\d+(?:(?:st|nd|rd|th)\b)?)
		 )?
		/iox,
		' ') # '
      s3e(e, $4, Format::ABBR_MONTHS[$2.downcase], $1,
	  $3 && $3[0,1].downcase == 'b')
      true
    end
  end

  def self._parse_us(str, e) # :nodoc:
    if str.sub!(
		/\b(#{Format::ABBR_MONTHS.keys.join('|')})[^-\d\s']*
		 \s*
		 ('?\d+)[^-\d\s']*
		 (?:
		   \s*
		   (c(?:e|\.e\.)|b(?:ce|\.c\.e\.)|a(?:d|\.d\.)|b(?:c|\.c\.))?
		   \s*
		   ('?-?\d+)
		 )?
		/iox,
		' ') # '
      s3e(e, $4, Format::ABBR_MONTHS[$1.downcase], $2,
	  $3 && $3[0,1].downcase == 'b')
      true
    end
  end

  def self._parse_iso(str, e) # :nodoc:
    if str.sub!(/([-+]?\d+)-(\d+)-(\d+)/, ' ')
      s3e(e, $1, $2, $3, false)
      true
    end
  end

  def self._parse_iso2(str, e) # :nodoc:
    if str.sub!(/\b(\d{2}|\d{4})?-?w(\d{2})(?:-?(\d))?\b/i, ' ')
      e[:cwyear] = $1.to_i if $1
      e[:cweek] = $2.to_i
      e[:cwday] = $3.to_i if $3
      true
    elsif str.sub!(/-w-(\d)\b/i, ' ')
      e[:cwday] = $1.to_i
      true
    elsif str.sub!(/--(\d{2})?-(\d{2})\b/, ' ')
      e[:mon] = $1.to_i if $1
      e[:mday] = $2.to_i
      true
    elsif str.sub!(/--(\d{2})(\d{2})?\b/, ' ')
      e[:mon] = $1.to_i
      e[:mday] = $2.to_i if $2
      true
    elsif /[,.](\d{2}|\d{4})-\d{3}\b/ !~ str &&
	str.sub!(/\b(\d{2}|\d{4})-(\d{3})\b/, ' ')
      e[:year] = $1.to_i
      e[:yday] = $2.to_i
      true
    elsif /\d-\d{3}\b/ !~ str &&
	str.sub!(/\b-(\d{3})\b/, ' ')
      e[:yday] = $1.to_i
      true
    end
  end

  def self._parse_jis(str, e) # :nodoc:
    if str.sub!(/\b([mtsh])(\d+)\.(\d+)\.(\d+)/i, ' ')
      era = { 'm'=>1867,
	      't'=>1911,
	      's'=>1925,
	      'h'=>1988
	  }[$1.downcase]
      e[:year] = $2.to_i + era
      e[:mon] = $3.to_i
      e[:mday] = $4.to_i
      true
    end
  end

  def self._parse_vms(str, e) # :nodoc:
    if str.sub!(/('?-?\d+)-(#{Format::ABBR_MONTHS.keys.join('|')})[^-]*
		-('?-?\d+)/iox, ' ')
      s3e(e, $3, Format::ABBR_MONTHS[$2.downcase], $1)
      true
    elsif str.sub!(/\b(#{Format::ABBR_MONTHS.keys.join('|')})[^-]*
		-('?-?\d+)(?:-('?-?\d+))?/iox, ' ')
      s3e(e, $3, Format::ABBR_MONTHS[$1.downcase], $2)
      true
    end
  end

  def self._parse_sla(str, e) # :nodoc:
    if str.sub!(%r|('?-?\d+)/\s*('?\d+)(?:\D\s*('?-?\d+))?|, ' ') # '
      if RUBY_VERSION >= '1.9.0'
        s3e(e, $1, $2, $3)
      else
        s3e(e, $3, $1, $2)
      end
      true
    end
  end

  def self._parse_dot(str, e) # :nodoc:
    if str.sub!(%r|('?-?\d+)\.\s*('?\d+)\.\s*('?-?\d+)|, ' ') # '
      if RUBY_VERSION >= '1.8.7'
        s3e(e, $1, $2, $3)
      else
        s3e(e, $3, $1, $2)
      end
      true
    end
  end

  def self._parse_year(str, e) # :nodoc:
    if str.sub!(/'(\d+)\b/, ' ')
      e[:year] = $1.to_i
      true
    end
  end

  def self._parse_mon(str, e) # :nodoc:
    if str.sub!(/\b(#{Format::ABBR_MONTHS.keys.join('|')})\S*/io, ' ')
      e[:mon] = Format::ABBR_MONTHS[$1.downcase]
      true
    end
  end

  def self._parse_mday(str, e) # :nodoc:
    if str.sub!(/(\d+)(st|nd|rd|th)\b/i, ' ')
      e[:mday] = $1.to_i
      true
    end
  end

  def self._parse_ddd(str, e) # :nodoc:
    if str.sub!(
		/([-+]?)(\d{2,14})
		  (?:
		    \s*
		    t?
		    \s*
		    (\d{2,6})?(?:[,.](\d*))?
		  )?
		  (?:
		    \s*
		    (
		      z\b
		    |
		      [-+]\d{1,4}\b
		    |
		      \[[-+]?\d[^\]]*\]
		    )
		  )?
		/ix,
		' ')
      case $2.size
      when 2
	if $3.nil? && $4
	  e[:sec]  = $2[-2, 2].to_i
	else
	  e[:mday] = $2[ 0, 2].to_i
	end
      when 4
	if $3.nil? && $4
	  e[:sec]  = $2[-2, 2].to_i
	  e[:min]  = $2[-4, 2].to_i
	else
	  e[:mon]  = $2[ 0, 2].to_i
	  e[:mday] = $2[ 2, 2].to_i
	end
      when 6
	if $3.nil? && $4
	  e[:sec]  = $2[-2, 2].to_i
	  e[:min]  = $2[-4, 2].to_i
	  e[:hour] = $2[-6, 2].to_i
	else
	  e[:year] = ($1 + $2[ 0, 2]).to_i
	  e[:mon]  = $2[ 2, 2].to_i
	  e[:mday] = $2[ 4, 2].to_i
	end
      when 8, 10, 12, 14
	if $3.nil? && $4
	  e[:sec]  = $2[-2, 2].to_i
	  e[:min]  = $2[-4, 2].to_i
	  e[:hour] = $2[-6, 2].to_i
	  e[:mday] = $2[-8, 2].to_i
	  if $2.size >= 10
	    e[:mon]  = $2[-10, 2].to_i
	  end
	  if $2.size == 12
	    e[:year] = ($1 + $2[-12, 2]).to_i
	  end
	  if $2.size == 14
	    e[:year] = ($1 + $2[-14, 4]).to_i
	    e[:_][:comp] = false
	  end
	else
	  e[:year] = ($1 + $2[ 0, 4]).to_i
	  e[:mon]  = $2[ 4, 2].to_i
	  e[:mday] = $2[ 6, 2].to_i
	  e[:hour] = $2[ 8, 2].to_i if $2.size >= 10
	  e[:min]  = $2[10, 2].to_i if $2.size >= 12
	  e[:sec]  = $2[12, 2].to_i if $2.size >= 14
	  e[:_][:comp] = false
	end
      when 3
	if $3.nil? && $4
	  e[:sec]  = $2[-2, 2].to_i
	  e[:min]  = $2[-3, 1].to_i
	else
	  e[:yday] = $2[ 0, 3].to_i
	end
      when 5
	if $3.nil? && $4
	  e[:sec]  = $2[-2, 2].to_i
	  e[:min]  = $2[-4, 2].to_i
	  e[:hour] = $2[-5, 1].to_i
	else
	  e[:year] = ($1 + $2[ 0, 2]).to_i
	  e[:yday] = $2[ 2, 3].to_i
	end
      when 7
	if $3.nil? && $4
	  e[:sec]  = $2[-2, 2].to_i
	  e[:min]  = $2[-4, 2].to_i
	  e[:hour] = $2[-6, 2].to_i
	  e[:mday] = $2[-7, 1].to_i
	else
	  e[:year] = ($1 + $2[ 0, 4]).to_i
	  e[:yday] = $2[ 4, 3].to_i
	end
      end
      if $3
	if $4
	  case $3.size
	  when 2, 4, 6
	    e[:sec]  = $3[-2, 2].to_i
	    e[:min]  = $3[-4, 2].to_i if $3.size >= 4
	    e[:hour] = $3[-6, 2].to_i if $3.size >= 6
	  end
	else
	  case $3.size
	  when 2, 4, 6
	    e[:hour] = $3[ 0, 2].to_i
	    e[:min]  = $3[ 2, 2].to_i if $3.size >= 4
	    e[:sec]  = $3[ 4, 2].to_i if $3.size >= 6
	  end
	end
      end
      if $4
	e[:sec_fraction] = Rational($4.to_i, 10**$4.size)
      end
      if $5
	e[:zone] = $5
	if e[:zone][0,1] == '['
	  o, n, = e[:zone][1..-2].split(':')
	  e[:zone] = n || o
	  if /\A\d/ =~ o
	    o = format('+%s', o)
	  end
	  e[:offset] = zone_to_diff(o)
	end
      end
      true
    end
  end

  private_class_method :_parse_day, :_parse_time, 
	:_parse_eu, :_parse_us, :_parse_iso, :_parse_iso2,
	:_parse_jis, :_parse_vms, :_parse_sla, :_parse_dot,
	:_parse_year, :_parse_mon, :_parse_mday, :_parse_ddd

  def self._parse(str, comp=true)
    str = str.dup

    e = {:_ => {:comp => comp}}
    str.gsub!(/[^-+',.\/:@[:alnum:]\[\]]+/, ' ')

    _parse_time(str, e)
    _parse_day(str, e)

    _parse_eu(str, e)     ||
    _parse_us(str, e)     ||
    _parse_iso(str, e)    ||
    _parse_jis(str, e)    ||
    _parse_vms(str, e)    ||
    _parse_sla(str, e)    ||
    _parse_dot(str, e)    ||
    _parse_iso2(str, e)   ||
    _parse_year(str, e)   ||
    _parse_mon(str, e)    ||
    _parse_mday(str, e)   ||
    _parse_ddd(str, e)

    if str.sub!(/\b(bc\b|bce\b|b\.c\.|b\.c\.e\.)/i, ' ')
      if e[:year]
	e[:year] = -e[:year] + 1
      end
    end

    if str.sub!(/\A\s*(\d{1,2})\s*\z/, ' ')
      if e[:hour] && !e[:mday]
	v = $1.to_i
	if (1..31) === v
	  e[:mday] = v
	end
      end
      if e[:mday] && !e[:hour]
	v = $1.to_i
	if (0..24) === v
	  e[:hour] = v
	end
      end
    end

    if e[:_][:comp]
      if e[:cwyear]
	if e[:cwyear] >= 0 && e[:cwyear] <= 99
	  e[:cwyear] += if e[:cwyear] >= 69
		      then 1900 else 2000 end
	end
      end
      if e[:year]
	if e[:year] >= 0 && e[:year] <= 99
	  e[:year] += if e[:year] >= 69
		    then 1900 else 2000 end
	end
      end
    end

    e[:offset] ||= zone_to_diff(e[:zone]) if e[:zone]

    e.delete(:_)
    e
  end

if RUBY_VERSION >= '1.9.0'
  def self._iso8601(str) # :nodoc:
    if /\A\s*(([-+]?\d{2,}|-)-\d{2}-\d{2}|
	      ([-+]?\d{2,})?-\d{3}|
	      (\d{2}|\d{4})?-w\d{2}-\d|
	      -w-\d)
	(t
	\d{2}:\d{2}(:\d{2}([,.]\d+)?)?
	(z|[-+]\d{2}(:?\d{2})?)?)?\s*\z/ix =~ str
      _parse(str)
    elsif /\A\s*(([-+]?(\d{2}|\d{4})|--)\d{2}\d{2}|
	      ([-+]?(\d{2}|\d{4}))?\d{3}|-\d{3}|
	      (\d{2}|\d{4})?w\d{2}\d)
	(t?
	\d{2}\d{2}(\d{2}([,.]\d+)?)?
	(z|[-+]\d{2}(\d{2})?)?)?\s*\z/ix =~ str
      _parse(str)
    elsif /\A\s*(\d{2}:\d{2}(:\d{2}([,.]\d+)?)?
	(z|[-+]\d{2}(:?\d{2})?)?)?\s*\z/ix =~ str
      _parse(str)
    elsif /\A\s*(\d{2}\d{2}(\d{2}([,.]\d+)?)?
	(z|[-+]\d{2}(\d{2})?)?)?\s*\z/ix =~ str
      _parse(str)
    end
  end

  def self._rfc3339(str) # :nodoc:
    if /\A\s*-?\d{4}-\d{2}-\d{2} # allow minus, anyway
	(t|\s)
	\d{2}:\d{2}:\d{2}(\.\d+)?
	(z|[-+]\d{2}:\d{2})\s*\z/ix =~ str
      _parse(str)
    end
  end

  def self._xmlschema(str) # :nodoc:
    if /\A\s*(-?\d{4,})(?:-(\d{2})(?:-(\d{2}))?)?
	(?:t
	  (\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?)?
	(z|[-+]\d{2}:\d{2})?\s*\z/ix =~ str
      e = {}
      e[:year] = $1.to_i
      e[:mon] = $2.to_i if $2
      e[:mday] = $3.to_i if $3
      e[:hour] = $4.to_i if $4
      e[:min] = $5.to_i if $5
      e[:sec] = $6.to_i if $6
      e[:sec_fraction] = Rational($7.to_i, 10**$7.size) if $7
      if $8
	e[:zone] = $8
	e[:offset] = zone_to_diff($8)
      end
      e
    elsif /\A\s*(\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?
	(z|[-+]\d{2}:\d{2})?\s*\z/ix =~ str
      e = {}
      e[:hour] = $1.to_i if $1
      e[:min] = $2.to_i if $2
      e[:sec] = $3.to_i if $3
      e[:sec_fraction] = Rational($4.to_i, 10**$4.size) if $4
      if $5
	e[:zone] = $5
	e[:offset] = zone_to_diff($5)
      end
      e
    elsif /\A\s*(?:--(\d{2})(?:-(\d{2}))?|---(\d{2}))
	(z|[-+]\d{2}:\d{2})?\s*\z/ix =~ str
      e = {}
      e[:mon] = $1.to_i if $1
      e[:mday] = $2.to_i if $2
      e[:mday] = $3.to_i if $3
      if $4
	e[:zone] = $4
	e[:offset] = zone_to_diff($4)
      end
      e
    end
  end

  def self._rfc2822(str) # :nodoc:
    if /\A\s*(?:(?:#{Format::ABBR_DAYS.keys.join('|')})\s*,\s+)?
	\d{1,2}\s+
	(?:#{Format::ABBR_MONTHS.keys.join('|')})\s+
	-?(\d{2,})\s+ # allow minus, anyway
	\d{2}:\d{2}(:\d{2})?\s*
	(?:[-+]\d{4}|ut|gmt|e[sd]t|c[sd]t|m[sd]t|p[sd]t|[a-ik-z])\s*\z/iox =~ str
      e = _parse(str, false)
      if $1.size < 4
	if e[:year] < 50
	  e[:year] += 2000
	elsif e[:year] < 1000
	  e[:year] += 1900
	end
      end
      e
    end
  end

  class << self; alias_method :_rfc822, :_rfc2822 end

  def self._httpdate(str) # :nodoc:
    if /\A\s*(#{Format::ABBR_DAYS.keys.join('|')})\s*,\s+
	\d{2}\s+
	(#{Format::ABBR_MONTHS.keys.join('|')})\s+
	-?\d{4}\s+ # allow minus, anyway
	\d{2}:\d{2}:\d{2}\s+
	gmt\s*\z/iox =~ str
      _rfc2822(str)
    elsif /\A\s*(#{Format::DAYS.keys.join('|')})\s*,\s+
	\d{2}\s*-\s*
	(#{Format::ABBR_MONTHS.keys.join('|')})\s*-\s*
	\d{2}\s+
	\d{2}:\d{2}:\d{2}\s+
	gmt\s*\z/iox =~ str
      _parse(str)
    elsif /\A\s*(#{Format::ABBR_DAYS.keys.join('|')})\s+
	(#{Format::ABBR_MONTHS.keys.join('|')})\s+
	\d{1,2}\s+
	\d{2}:\d{2}:\d{2}\s+
	\d{4}\s*\z/iox =~ str
      _parse(str)
    end
  end

  def self._jisx0301(str) # :nodoc:
    if /\A\s*[mtsh]?\d{2}\.\d{2}\.\d{2}
	(t
	(\d{2}:\d{2}(:\d{2}([,.]\d*)?)?
	(z|[-+]\d{2}(:?\d{2})?)?)?)?\s*\z/ix =~ str
      if /\A\s*\d/ =~ str
	_parse(str.sub(/\A\s*(\d)/, 'h\1'))
      else
	_parse(str)
      end
    else
      _iso8601(str)
    end
  end
end
end

if RUBY_VERSION >= '1.9.0'
class DateTime

  def iso8601_timediv(n) # :nodoc:
    strftime('T%T' +
	     if n < 1
	       ''
	     else
	       '.%0*d' % [n, (sec_fraction / Rational(1, 10**n)).round]
	     end +
	     '%:z')
  end

  private :iso8601_timediv

  def iso8601(n=0)
    super() + iso8601_timediv(n)
  end

  def rfc3339(n=0) iso8601(n) end

  def xmlschema(n=0) iso8601(n) end # :nodoc:

  def jisx0301(n=0)
    super() + iso8601_timediv(n)
  end

end
end
