# --
# Copyright (C) 2017 Edicarlos Lopes dos Santos <edicarlos.lds at gmail.com>
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::pt_BR_AccountedTimeStats;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;

	# frontend template overview
    $Self->{Translation}->{'Accounted Time Stats'} = 'Estatísticas de Tempo Contabilizado';
    $Self->{Translation}->{'Here you can see the accounted time stats.'} = 'Aqui você pode visualizar as estatísticas de tempo contabilizado.';
    $Self->{Translation}->{'Search Params'} = 'Parâmetros da Pesquisa';
    $Self->{Translation}->{'On any date.'} = 'Em qualquer data.';
    $Self->{Translation}->{'Accounted time between'} = 'Tempo Contabilizado entre';
    $Self->{Translation}->{'Type View'} = 'Tipo de Visão';
    $Self->{Translation}->{'Only accounted time by selected agent(s).'} = 'Somente o tempo contabilizado pelo(s) atendente(s) selecionado(s).';
	
	# frontend template screen view
    $Self->{Translation}->{'Screen View'} = 'Exibição em Tela';
    $Self->{Translation}->{'Ticket List'} = 'Lista de Chamados';
}

1;
