#pragma once

namespace PsqlTools::PsqlUtils::Spi {

    class SpiSession {
    public:
        SpiSession();
        ~SpiSession();

        void execute_read_select();
    };

} // namespace PsqlTools::PsqlUtilsSpi