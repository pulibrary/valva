#!/usr/bin/env ruby
# frozen_string_literal: true

# For the Valva project
# Creates marc records from a spreadsheet
# 201911

require 'csv'
require 'marc'
require 'optparse'
require 'facets/string/titlecase'

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: convert.rb [options]'
  opts.on('-f', '--file FILE', 'File to process') do |f|
    options[:file] = f # f == the filename given after -f or --file
  end
end.parse!

def field_sort(record)
  new_rec = MARC::Record.new
  new_rec.leader = record.leader
  record.fields('001'..'009').sort_by(&:tag).each do |field|
    new_rec.append(field)
  end
  record.fields('010'..'099').each do |field|
    new_rec.append(field)
  end
  record.fields('100'..'199').each do |field|
    new_rec.append(field)
  end
  record.fields('200'..'299').each do |field|
    new_rec.append(field)
  end
  record.fields('300'..'399').each do |field|
    new_rec.append(field)
  end
  record.fields('500'..'599').each do |field|
    new_rec.append(field)
  end
  record.fields('600'..'699').each do |field|
    new_rec.append(field)
  end
  record.fields('700'..'799').each do |field|
    new_rec.append(field)
  end
  new_rec
end

## process contributer fields
## composer, lyracist, arranger
def process_contributers(contributer, record, tag, role)
  comp = contributer.split(';').map(&:strip) if contributer
  fuller = nil
  death = nil
  name = nil
  return unless comp

  token_count = 0
  comp.each do |c|
    token_count += 1
    next if (tag == '700') && (role == 'composer') && (token_count == 1) # skip the first token

    tokens = c.split('ǂ')
    # if starts with d or q => subf, else new a
    tokens.each do |token|
      if token =~ /^q /
        fuller = token.gsub(/^q /, '').strip
      elsif token =~ /^d /
        death = token.gsub(/^d /, '').strip
      else
        name = token.strip
      end
    end
    if fuller && death
      punct = !death.end_with?('-') ? ',' : ''
      record.append(MARC::DataField.new(tag, '1', ' ', ['a', name], ['q', fuller], ['d', death + punct], ['e', role]))
    elsif death && !fuller
      punct = !death.end_with?('-') ? ',' : ''
      record.append(MARC::DataField.new(tag, '1', ' ', ['a', name], ['d', death + punct], ['e', role]))
    elsif fuller && !death
      record.append(MARC::DataField.new(tag, '1', ' ', ['a', name], ['e', fuller + ','], ['e', role]))
    else
      record.append(MARC::DataField.new(tag, '1', ' ', ['a', name + ','], ['e', role]))
    end
    break if tag == '100'
  end
end

## write out marc records
def write_marc(options)
  xwriter = MARC::XMLWriter.new('./out/valva.xml')
  bwriter = MARC::Writer.new('./out/valva.mrc')
  input = CSV.read(options[:file], headers: true, encoding: 'UTF-8')
  counter = 1
  input.each do |line|
    record = MARC::Record.new
    ti_article = line[1]&.strip
    ti_ind2 = ti_article ? (ti_article.length + 1).to_s : '0'
    title = line[2]&.strip
    subtitle = line[3]&.strip
    composer = line[4]&.strip
    arranger = line[5]&.strip
    lyracist = line[6]&.strip
    pub_loc = line[7]&.strip
    publisher = line[8]&.strip
    pub_date = line[9]&.strip
    plate_num = line[10]&.strip
    instrument = line[11]&.strip
    notes = line[12]&.strip
    box_folder = line[13]&.strip

    ## LDR
    record.leader = '00000ccm a2200433 i 4500' # printed music

    ## 008
    date1 = pub_date || '1875'
    date2 = pub_date || '1930'
    pub_status = pub_date ? 't' : 'q'
    place = 'xxu'
    cf008 = "190531#{pub_status}#{date1}#{date2}#{place}uuze        n    zxx d"
    record.append(MARC::ControlField.new('008', cf008))

    ## 028
    if plate_num
      record.append(MARC::DataField.new('028', '2', '0', ['a', plate_num], ['b', publisher]))
    end

    ## 040
    record.append(MARC::DataField.new('040', ' ', ' ', %w[a NjP], %w[b eng], %w[c NjP]))

    ## 100
    process_contributers(composer, record, '100', 'composer')

    ## 245
    if subtitle
      record.append(MARC::DataField.new('245', '1', ti_ind2, ['a', title + ' :'], ['b', subtitle]))
    else
      record.append(MARC::DataField.new('245', '1', ti_ind2, ['a', title]))
    end

    ## 264
    if pub_date
      if pub_loc && publisher
        record.append(MARC::DataField.new('264', ' ', '1', ['a', pub_loc + ' :'], ['b', publisher + ','], ['c', '[' + pub_date + ']']))
      elsif publisher && pub_loc.nil?
        record.append(MARC::DataField.new('264', ' ', '1', ['b', publisher + ','], ['c', '[' + pub_date + ']']))
      end
      record.append(MARC::DataField.new('264', ' ', '4', ['c', '©' + pub_date]))
    elsif !pub_date
      if pub_loc && publisher
        record.append(MARC::DataField.new('264', ' ', '1', ['a', pub_loc + ' :'], ['b', publisher + ','], ['c', '[between 1875 and 1930]']))
      elsif publisher && pub_loc.nil?
        record.append(MARC::DataField.new('264', ' ', '1', ['b', publisher + ','], ['c', '[between 1875 and 1930]']))
      else
        record.append(MARC::DataField.new('264', ' ', '1', ['c', '[between 1875 and 1930]']))
      end
    end

    ## 33x
    record.append(MARC::DataField.new('336', ' ', ' ', ['a', 'notated music'], %w[b ntm], %w[2 rdacontent]))
    record.append(MARC::DataField.new('337', ' ', ' ', %w[a unmediated], %w[b n], %w[2 rdamedia]))
    record.append(MARC::DataField.new('338', ' ', ' ', %w[a volume], %w[b nc], %w[2 rdacontent]))

    ## 348
    record.append(MARC::DataField.new('348', ' ', ' ', %w[a part], %w[2 rdanfm]))

    ## 500
    if instrument
      record.append(MARC::DataField.new('500', ' ', ' ', ['a', 'Instrumentation: ' + instrument.downcase]))
    end
    record.append(MARC::DataField.new('500', ' ', ' ', ['a', notes])) if notes
    if box_folder
      record.append(MARC::DataField.new('500', ' ', ' ', ['a', 'Box and folder number: ' + box_folder]))
    end

    ## 546
    record.append(MARC::DataField.new('546', ' ', ' ', ['b', 'Staff notation']))

    # 65x
    record.append(MARC::DataField.new('650', ' ', '0', ['a', 'Silent film music']))
    record.append(MARC::DataField.new('655', ' ', '7', ['a', 'Parts (Music)'], %w[2 lcgft]))
    record.append(MARC::DataField.new('655', ' ', '7', ['a', 'Silent film music'], %w[2 lcgft]))

    ## 700
    process_contributers(composer, record, '700', 'composer')
    process_contributers(arranger, record, '700', 'arranger')
    process_contributers(lyracist, record, '700', 'lyracist')

    ## 730
    record.append(MARC::DataField.new('730', '0', ' ', ['a', 'Fred D. Valva Collection of Silent Film and Vaudeville Theater Orchestra Music.']))
    record.append(MARC::DataField.new('730', '0', ' ', ['a', 'Fred D. Valva Collection of Silent Film and Vaudeville Theatre Orchestra Music.']))

    # record = field_sort(record)
    # xwriter = MARC::XMLWriter.new("./out/marc#{counter}.xml")
    xwriter.write(record)
    # bwriter = MARC::Writer.new("./out/marc#{counter}.mrc")
    bwriter.write(record)
    counter += 1
    puts record
  end
end

write_marc(options)
