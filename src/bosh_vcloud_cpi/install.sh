brew install libiconv
brew install libxml2
bundle config build.nokogiri "--use-system-libraries --with-xml2-include=/usr/local/opt/libxml2/include/libxml2" --with-iconv-dir=/usr/local/Cellar/libiconv/1.16/