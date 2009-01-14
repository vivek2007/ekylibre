# == Schema Information
# Schema version: 20081127140043
#
# Table name: financialyears
#
#  id           :integer       not null, primary key
#  code         :string(12)    not null
#  closed       :boolean       not null
#  started_on   :date          not null
#  stopped_on   :date          not null
#  written_on   :date          not null
#  company_id   :integer       not null
#  created_at   :datetime      not null
#  updated_at   :datetime      not null
#  created_by   :integer       
#  updated_by   :integer       
#  lock_version :integer       default(0), not null
#

class Financialyear < ActiveRecord::Base
  #validates_uniqueness_of [:started_on, :stopped_on]


  def before_validation
    #self.code = name.to_s[0..7].simpleize if code.blank?
    #self.code = rand.to_s[2..100].to_i.to_s(36)[0..7] if code.blank?
    self.code.upper!
    while Financialyear.count(:conditions=>["code=? AND id!=?",self.code, self.id]) > 0 do
      self.code.succ!
    end
    
  end

  
  def validate
    errors.add_to_base lc(:error_period_financialyear) if self.started_on > self.stopped_on
    if JournalPeriod.count > 0
      periods = JournalPeriod.find_all_by_company_id(self.company_id, :order=>"stopped_on DESC")  
      periods.each do |period|
        errors.add_to_base lc(:error_financialyear) if self.started_on < period.stopped_on 
      end
    end
  end
  
  # When a financial year is closed, all the matching journals are closed too. 
  def close(date)
    self.update_attributes(:stopped_on => date, :closed => true)
    periods = JournalPeriod.find_all_by_financialyear_id(self.id)
    #puts 'donnees:'+self.journal_periods.inspect
    if periods.size > 0
      periods.each do |period|
        period.journal.close(date)
      end
    end
  end
  
end
