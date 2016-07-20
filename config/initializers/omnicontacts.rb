#check https://github.com/Diego81/omnicontacts for more info

require "omnicontacts"

Rails.application.middleware.use OmniContacts::Builder do
  #importer :gmail, "1086115038356.apps.googleusercontent.com", "XAlFDjrXDQvaFc5tlS6biftG", {:redirect_path => "/invites/gmail/contact_callback"}
  #importer :gmail, "1086115038356.apps.googleusercontent.com", "XAlFDjrXDQvaFc5tlS6biftG", {:redirect_path => "/contacts/gmail/contact_callback"}
  
  #importer :gmail, "376013845018-4mq3imjn04p4balcor55hifnhphh8ele.apps.googleusercontent.com", "-fD8ioqy0CKiQGeRECp8UmzV" , {:redirect_path => "/contacts/gmail/contact_callback"}
#importer :gmail, "376013845018-3foo4dtkdgpuk6f45j8oron92kjnpvp7.apps.googleusercontent.com", "dZHsAV-eKXiKoE21xjQuD1wD" , {:redirect_path => "/contacts/gmail/contact_callback"}
 ############local
 #importer :gmail, "376013845018-t630vuiqsj3gba1pobce4r3jf0ovaf84.apps.googleusercontent.com", "b733352bf231a718c5b7bea6f088551440cd8ed0" , {:redirect_path => "/contacts/gmail/contact_callback"}
# for staging 3002
if Rails.env == "development"
  #for staging.wakeupsales.com:3002
 importer :gmail, "376013845018-7e8vg3p57learcokhif2uffmnve9i59k.apps.googleusercontent.com", "x-ge33eWngux745ap7gR6mAT", {:redirect_path => "/contact_callback"}
 #for localhost:3001
 
 #importer :gmail, "376013845018-jd2qfkd6b35p7n0ijne8ags5rf47eusv.apps.googleusercontent.com", "wH0RnhemFNxScLBXk6tu25wQ", {:redirect_path => "/testgmail"}
 #importer :gmail, "376013845018-jdg55ursh8dkfvaau1rmq8immv8br7dp.apps.googleusercontent.com", "d2gEVDXQuqm4tpXYDVBX4vZC", {:redirect_path => "/contact_callback"}
end
if Rails.env == "production"
 importer :gmail, "1036043446404-ucpu9ksbvee625konimjs1vlrlfev6vm.apps.googleusercontent.com", "EhUFzGrxHs0NFLIBF0NVMK_w", {:redirect_path => "/contact_callback"}
end
  #importer :yahoo, "dj0yJmk9WEFzREpidHBJM1U5JmQ9WVdrOWR6bEViM0ZrTTJVbWNHbzlPRGswTVRBMU9EWXkmcz1jb25zdW1lcnNlY3JldCZ4PTgw", "c43984c5cac8b07431dc0a4f4ab7f04776bdca7f", {:callback_path => '/invites/yahoo/contact_callback'} 
  #importer :hotmail, "client_id", "client_secreat"
end
