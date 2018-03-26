# --
# Custom/Kernel/Modules/AgentAccountedTimeStats.pm - frontend module
# Copyright (C) 2017 Edicarlos Lopes dos Santos <edicarlos.lds at gmail.com>
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentAccountedTimeStats;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );
	
	$Self->{TicketList} = [];
	
    return $Self;
}

sub Run {
	my ( $Self, %Param ) = @_;

	my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
	my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
	my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');
	
	# ------------------------------------------------------------ #
    # overview
    # ------------------------------------------------------------ #
	if ( $Self->{Subaction} eq 'Overview' ) {
        return $Self->_Overview(
            %Param,
        );
    }
	
	# ------------------------------------------------------------ #
    # search results
    # ------------------------------------------------------------ #
	elsif ( $Self->{Subaction} eq 'Search' ) {
	
		# get params
		$Param{OutputFormat} = $ParamObject->GetParam( Param => 'OutputFormat' );
		$Param{TimeSearchType} = $ParamObject->GetParam( Param => 'TimeSearchType' );
		$Param{PageNavBarFilter} = $ParamObject->GetParam( Param => 'PageNavBarFilter' );
		$Param{OwnerTimeView} = $ParamObject->GetParam( Param => 'OwnerTimeView' );
		
		# return results from page nav bar
		if( $Param{PageNavBarFilter} ){
			return $Self->_TicketListView(
				%Param,
			);		
		}
	
		# get array params
        for my $Parameter ( qw( QueueIDs OwnerIDs ) ) {
		
            # get search array params (get submitted params)
            if ( $ParamObject->GetArray( Param => $Parameter ) ) {
                @{ $Param{$Parameter} } = $ParamObject->GetArray( Param => $Parameter );
            }
        }
		
		# get time params
		for my $Attribute (
            qw(
				TimePoint TimePointFormat TimePointStart
				TimeStartDay TimeStartMonth TimeStartYear
				TimeStopDay TimeStopYear TimeStopMonth
            )
        ){
            $Param{$Attribute} = $ParamObject->GetParam( Param => $Attribute );
        }

        # validate date
        for my $Validate (
            qw( TimeStartDay TimeStartMonth TimeStopDay TimeStopMonth )
            )
        {
            if ( $Param{$Validate} ) {
                $Param{$Validate} = sprintf( '%02d', $Param{$Validate} );
            }
        }
		
		# format date filter
		if ( $Param{TimeSearchType} eq 'TimeSlot' ) {
			for (qw(TimePoint TimePointFormat TimePointStart)) {
				delete $Param{ $_ };
			}		
		
			if (
				$Param{ TimeStartDay }
				&& $Param{ TimeStartMonth }
				&& $Param{ TimeStartYear }
				)
			{
				$Param{ ArticleCreateTimeNewerDate } = $Param{ TimeStartYear } . '-'
					. $Param{ TimeStartMonth } . '-'
					. $Param{ TimeStartDay }
					. ' 00:00:01';
			}	
			
			if (
				$Param{ TimeStopDay }
				&& $Param{ TimeStopMonth }
				&& $Param{ TimeStopYear }
				)
			{
				$Param{ ArticleCreateTimeOlderDate } = $Param{ TimeStopYear } . '-'
					. $Param{ TimeStopMonth } . '-'
					. $Param{ TimeStopDay }
					. ' 23:59:59';
			}	
		}
		elsif ( $Param{TimeSearchType} eq 'TimePoint' ) {
			for (
				qw( TimeStartDay TimeStartMonth TimeStartYear
				TimeStopDay TimeStopMonth TimeStopYear )
			){
				delete $Param{ $_ };
			}
			if (
				$Param{TimePoint}
				&& $Param{TimePointStart}
				&& $Param{TimePointFormat}
				)
			{				
				my $Time = 0;
				my ($TimeOlderMinutes, $TimeNewerMinutes);				
				
				if ( $Param{TimePointFormat} eq 'minute' ) {
					$Time = $Param{TimePoint};
				}
				elsif ( $Param{TimePointFormat} eq 'hour' ) {
					$Time = $Param{TimePoint} * 60;
				}
				elsif ( $Param{TimePointFormat} eq 'day' ) {
					$Time = $Param{TimePoint} * 60 * 24;
				}
				elsif ( $Param{TimePointFormat} eq 'week' ) {
					$Time = $Param{TimePoint} * 60 * 24 * 7;
				}
				elsif ( $Param{TimePointFormat} eq 'month' ) {
					$Time = $Param{TimePoint} * 60 * 24 * 30;
				}
				elsif ( $Param{TimePointFormat} eq 'year' ) {
					$Time = $Param{TimePoint} * 60 * 24 * 365;
				}			
				
				if ( $Param{TimePointStart} eq 'Before' ) {				
					# more than ... ago
					$TimeOlderMinutes = $Time;				
				}
				elsif ( $Param{TimePointStart} eq 'Next' ) {

					# within the next ...
					$TimeNewerMinutes = 0;
					$TimeOlderMinutes = -$Time;
				}
				else {

					# within the last ...
					$TimeOlderMinutes = 0;
					$TimeNewerMinutes = $Time;
				}
				
				# format to timestamp				
				my $SystemTimeNewer = $TimeObject->SystemTime();
				$SystemTimeNewer -= ( $TimeNewerMinutes * 60 );

				$Param{ArticleCreateTimeNewerDate} = $TimeObject->SystemTime2TimeStamp(
					SystemTime => $SystemTimeNewer,
				);
				
				my $SystemTimeOlder = $TimeObject->SystemTime();
				$SystemTimeOlder -= ( $TimeOlderMinutes * 60 );

				$Param{ArticleCreateTimeOlderDate} = $TimeObject->SystemTime2TimeStamp(
					SystemTime => $SystemTimeOlder,
				);
			}			
		}
		
		# search
		return $Self->_TicketListView(
			%Param,
		);
	}
	
	# ------------------------------------------------------------ #
    # update preferences from page nav bar
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Update' ) {
	
		my $UserObject   = $Kernel::OM->Get('Kernel::System::User');

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $Message  = '';
        my $Priority = '';

        # check group param
        my @Groups = $ParamObject->GetArray( Param => 'Group' );
        if ( !@Groups ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Param Group is required!'),
            );
        }

        for my $Group (@Groups) {

            # check preferences setting
            my %Preferences = %{ $Kernel::OM->Get('Kernel::Config')->Get('PreferencesGroups') };
            if ( !$Preferences{$Group} ) {
                return $LayoutObject->ErrorScreen(
                    Message => $LayoutObject->{LanguageObject}->Translate( 'No such config for %s', $Group ),
                );
            }

            # get user data
            my %UserData = $UserObject->GetUserData( UserID => $Self->{UserID} );
            my $Module = $Preferences{$Group}->{Module};
            if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($Module) ) {
                return $LayoutObject->FatalError();
            }

            my $Object = $Module->new(
                %{$Self},
                UserObject => $UserObject,
                ConfigItem => $Preferences{$Group},
                Debug      => $Self->{Debug},
            );
            my @Params = $Object->Param( UserData => \%UserData );
            my %GetParam;
            for my $ParamItem (@Params) {
                my @Array = $ParamObject->GetArray(
                    Param => $ParamItem->{Name},
                    Raw   => $ParamItem->{Raw} || 0,
                );
                if ( defined $ParamItem->{Name} ) {
                    $GetParam{ $ParamItem->{Name} } = \@Array;
                }
            }

            if (
                $Object->Run(
                    GetParam => \%GetParam,
                    UserData => \%UserData
                )
                )
            {
                $Message .= $Object->Message();
            }
            else {
                $Priority .= 'Error';
                $Message  .= $Object->Error();
            }
        }        

        # check redirect
        my $RedirectURL = $ParamObject->GetParam( Param => 'RedirectURL' );
        if ($RedirectURL) {
		
			# load new URL in parent window and close popup
            return $LayoutObject->PopupClose(
				URL => $RedirectURL,
			);
        }

        # redirect
        return $LayoutObject->PopupClose(
            URL => "Action=AgentPreferences;Priority=$Priority;Message=$Message",
        );
    }
	
	return $Self->_Overview(
        %Param,
    );

}

sub _TicketListView{
	my ( $Self, %Param ) = @_;	
		
	my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
	my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
	my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
		
	# search in archive
    if (
        $ConfigObject->Get('Ticket::ArchiveSystem')
        && !$ConfigObject->Get('Ticket::CustomerArchiveSystem')
    )
    { 	
        $Param{ArchiveFlags} = [ 'y', 'n' ];
    }
	
	# create filters to ticket search
	my %TicketFilters;
	if( $Param{PageNavBarFilter} ) {
		%TicketFilters = $Self->_GetPreferences();
		%Param = %TicketFilters;
		$Param{OutputFormat} = 'Screen';
	}
	else{
		$Self->_SetPreferences(%Param);		
		%TicketFilters = %Param;
	}
	
	# remove owners from search if owner view is active
	if( $Param{OwnerTimeView} ){
		delete $TicketFilters{OwnerIDs};
	}	
	
	my @TicketIDs = $TicketObject->TicketSearch(
		Result => 'ARRAY',
		%TicketFilters,
		UserID => $Self->{UserID},
	);	
	
	# get default columns
	my $Columns = $ConfigObject->Get('AccountedTimeStats::TicketsView::DefaultOverviewColumns') || {};
	my @Header;
	for my $Column ( keys %{$Columns} ) {
		if ( $Columns->{$Column} ) {
			push @Header, $Column;
		}
	}
	
	# add default column
	push @Header, 'AccountedTime';
	
	# html output
	if( $Param{OutputFormat} eq 'Screen' ){	
	
		my $TicketData = $Self->_GetTicketData( 
			TicketIDs => \@TicketIDs,
			%TicketFilters,
			%Param
		);		
		
		$Param{Total} = scalar @{$TicketData};
		
		# check start option
		my $StartHit = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'StartHit' ) || 1;

		# get personal page shown count
		my $PageShownPreferencesKey = 'AccountedTimeOverviewPageShown';
		my $PageShown               = $Self->{$PageShownPreferencesKey} || 35;
		my $Group                   = 'AccountedTimeOverviewPageShown';

		# get data selection
		my %Data;
		my $Config = $ConfigObject->Get('PreferencesGroups');
		if ( $Config && $Config->{$Group} && $Config->{$Group}->{Data} ) {
			%Data = %{ $Config->{$Group}->{Data} };
		}

		# calculate max. shown per page
		if ( $StartHit > $Param{Total} ) {
			my $Pages = int( ( $Param{Total} / $PageShown ) + 0.99999 );
			$StartHit = ( ( $Pages - 1 ) * $PageShown ) + 1;
		}

		# build nav bar
		my $Limit = $Param{Limit} || 20_000;
		my %PageNav = $LayoutObject->PageNavBar(
			Limit     => $Limit,
			StartHit  => $StartHit,
			PageShown => $PageShown,
			AllHits   => $Param{Total} || 0,
			Action    => 'Action=' . $LayoutObject->{Action}.';Subaction=Search;PageNavBarFilter=1',
			Link      => $Param{LinkPage},
			IDPrefix  => $LayoutObject->{Action},
		);

		# build shown dynamic fields per page
		$Param{RequestedURL}    = "Action=$Self->{Action}";
		$Param{Group}           = $Group;
		$Param{PreferencesKey}  = $PageShownPreferencesKey;
		$Param{PageShownString} = $LayoutObject->BuildSelection(
			Name        => $PageShownPreferencesKey,
			SelectedID  => $PageShown,
			Translation => 0,
			Data        => \%Data,
		);

		if (%PageNav) {
			$LayoutObject->Block(
				Name => 'OverviewNavBarPageNavBar',
				Data => \%PageNav,
			);

			$LayoutObject->Block(
				Name => 'ContextSettings',
				Data => { %PageNav, %Param, },
			);
		}
		
		for my $HeaderItem (@Header){
			$LayoutObject->Block(
				Name => 'Header',
				Data => { HeaderItem => $HeaderItem },
			);
		}
		
		if ( $Param{Total} ) {
		 
			my $Counter = 0;	
			my $AccountedTimeTotal = 0;			
			
			for my $Ticket ( @{ $TicketData } ){
			
				$Counter++;
				if ( $Counter >= $StartHit && $Counter < ( $PageShown + $StartHit ) ) {
				
					$LayoutObject->Block(
						Name => 'Row',
						Data => {},
					);
				
					# create row output
					for my $DataItem (@Header){
						$LayoutObject->Block(
							Name => 'ItemRow',
							Data => { DataItem => $Ticket->{$DataItem} },
						);
					}			
				}
				
				# get accounted time
				$AccountedTimeTotal += $Ticket->{AccountedTime};						
			}

			# show subtotal
			if( ($Param{Total} - $StartHit ) <= $PageShown ){
				$LayoutObject->Block(
					Name => 'Subtotal',
					Data => {
						Colspan => (scalar @Header)-1,
						AccountedTimeTotal => $AccountedTimeTotal
					}
				)
			}		
		}
		else{
			$LayoutObject->Block(
				Name => 'NoDataFound',
				Data => {}
			)
		}
	
		my $Output = $LayoutObject->Header(
			Title => Translatable('Screen View'),
			Type  => 'Small',
		);
		$Output .= $LayoutObject->Output(
			TemplateFile => 'Statistics/ScreenView',
			Data => {				
				%Param,
			},            
		);
		$Output .= $LayoutObject->Footer(
			Type => 'Small',
		);
		
		return $Output;
	}
	
	# pdf output
    elsif ( $Param{OutputFormat} eq 'Print' ) {
	
		# create title
		my $Title =  $LayoutObject->{LanguageObject}->Translate('Accounted Time Stats');
		
		# generate filename
		my $Filename = $Kernel::OM->Get('Kernel::System::Stats')->StringAndTimestamp2Filename(
			String   => $Title || 'Export',
		);
		
		my @DataArray = ();
		
		my $TicketData = $Self->_GetTicketData( 
			TicketIDs => \@TicketIDs, 
			%TicketFilters,
			%Param
		);
		
		my $AccountedTimeTotal = 0;		
		for my $Ticket ( @{ $TicketData } ){
		
			my @TicketArray = ();		
			for my $DataItem (@Header){
				push @TicketArray, $Ticket->{$DataItem};
			}	
			
			push @DataArray, \@TicketArray;
			$AccountedTimeTotal += $Ticket->{AccountedTime};						
		}
		
		# create structure to show subtotal
		my @SubtotalArray = ('Subtotal');
		
		my $Counter = scalar @Header;
		for (1..$Counter-2){
			push @SubtotalArray, '';
		}
		push @SubtotalArray, $AccountedTimeTotal;
		
		push @DataArray, \@SubtotalArray;
	
        my $PDFString = $Self->_GeneratePDF(
            Title        => $Title,
            HeadArrayRef => \@Header,
            DataArray    => \@DataArray,
            UserID       => $Self->{UserID},
        );
        return $LayoutObject->Attachment(
            Filename    => $Filename . '.pdf',
            ContentType => 'application/pdf',
            Content     => $PDFString,
            Type        => 'inline',
        );
    }
	
	# generate excel/csv output
    elsif ( $Param{OutputFormat} eq 'Excel' || $Param{OutputFormat} eq 'CSV' ) {
	
		my $CSVObject = $Kernel::OM->Get('Kernel::System::CSV');
		
		# create title
		my $Title =  $LayoutObject->{LanguageObject}->Translate('Accounted Time Stats');
		
		# generate filename
		my $Filename = $Kernel::OM->Get('Kernel::System::Stats')->StringAndTimestamp2Filename(
			String   => $Title || 'Export',
		);
		
		my @DataArray = ();
		
		my $TicketData = $Self->_GetTicketData(
			TicketIDs => \@TicketIDs, 
			%TicketFilters,
			%Param
		);
		
		# create data structure to show in CSV/Excel
		my $AccountedTimeTotal = 0;		
		for my $Ticket ( @{ $TicketData } ){
		
			my @TicketArray = ();		
			for my $DataItem (@Header){
				push @TicketArray, $Ticket->{$DataItem};
			}	
			
			push @DataArray, \@TicketArray;
			$AccountedTimeTotal += $Ticket->{AccountedTime};						
		}
		
		# create structure to show subtotal
		my @SubtotalArray = ('Subtotal');
		
		my $Counter = scalar @Header;
		for (1..$Counter-2){
			push @SubtotalArray, '';
		}
		push @SubtotalArray, $AccountedTimeTotal;
		
		push @DataArray, \@SubtotalArray;
	
        my $Content = $CSVObject->Array2CSV(
            Head   => \@Header,
            Data   => \@DataArray,
            Format => $Param{OutputFormat},
        );
		
		my $FileExtension = $Param{OutputFormat} eq 'CSV' ? '.csv' : '.xlsx';

        return $LayoutObject->Attachment(
            Filename    => $Filename . $FileExtension,
            ContentType => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            Content     => $Content,
        );
    }
}

sub _SetPreferences{
	my ( $Self, %Param ) = @_;

	my $UserObject   = $Kernel::OM->Get('Kernel::System::User');
	
	my $Key = 'AccountedTimeStats';
	
	for my $ArrayParameter ( qw(OwnerIDs QueueIDs) ){		
		if( IsArrayRefWithData($Param{$ArrayParameter}) ){
			my $ArrayStrg = join(';',@{ $Param{$ArrayParameter} });			
			$UserObject->SetPreferences(
				Key    => $Key.'_'.$ArrayParameter,
				Value  => $ArrayStrg,
				UserID => $Self->{UserID},
			);			
		}
		else{
			$UserObject->SetPreferences(
				Key    => $Key.'_'.$ArrayParameter,
				Value  => '',
				UserID => $Self->{UserID},
			);		
		}
	}
	
	for my $ScalarParameter ( qw(ArticleCreateTimeNewerDate ArticleCreateTimeOlderDate OwnerTimeView ) ){
		if( $Param{$ScalarParameter} ){
			$UserObject->SetPreferences(
				Key    => $Key.'_'.$ScalarParameter,
				Value  => $Param{$ScalarParameter},
				UserID => $Self->{UserID},
			);		
		}
		else{
			$UserObject->SetPreferences(
				Key    => $Key.'_'.$ScalarParameter,
				Value  => '',
				UserID => $Self->{UserID},
			);		
		}
	}
	
	return 1;
}

sub _GetPreferences{
	my ( $Self, %Param ) = @_;

	my $UserObject   = $Kernel::OM->Get('Kernel::System::User');
	
	my $Key = 'AccountedTimeStats';
	my %Data = ();
	
	for my $ArrayParameter ( qw(OwnerIDs QueueIDs) ){		
		my %Preferences = $UserObject->SearchPreferences(
			Key   => $Key.'_'.$ArrayParameter,
		);
		
		if( IsHashRefWithData(\%Preferences) ){
			my @Array = split /;/, $Preferences{$Self->{UserID}};
			
			if( IsArrayRefWithData(\@Array) ){
				$Data{$ArrayParameter} = \@Array;
			}
		}
	}
	
	for my $ScalarParameter ( qw(ArticleCreateTimeNewerDate ArticleCreateTimeOlderDate OwnerTimeView ) ){
		my %Preferences = $UserObject->SearchPreferences(
			Key   => $Key.'_'.$ScalarParameter,
		);
		
		if( IsHashRefWithData(\%Preferences) ){
			$Data{$ScalarParameter} = $Preferences{$Self->{UserID}};
		}
	}
	
	return %Data;
}

sub _GetTicketData{
	my ( $Self, %Param ) = @_;
	
	# check needed stuff
    if ( ! defined $Param{TicketIDs} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Needed QueueIDs!',
        );
        return;
    }
	
	my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');
	my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
	my $UserObject   = $Kernel::OM->Get('Kernel::System::User');
	my $ArticleObject = $Kernel::OM->Get('Kernel::System::Ticket::Article');
	
	my @Data = ();
		
	# get accounted time by article
 	foreach my $TicketID ( sort @{ $Param{TicketIDs} } ){
	
		my %TicketData = ();
		$TicketData{AccountedTime} = 0;
	
 		my @ArticleList = $ArticleObject->ArticleList(
 			TicketID => $TicketID
 		);
		
		ARTICLE:
		foreach my $ArticleMetaData (@ArticleList){
			next ARTICLE if !$ArticleMetaData;
			next ARTICLE if !IsHashRefWithData($ArticleMetaData);
			
			# get only article added by agent
			if( $Param{OwnerTimeView} && IsArrayRefWithData( $Param{OwnerIDs} ) ){
				if ( !grep { $_ eq $ArticleMetaData->{CreateBy} } @{$Param{OwnerIDs}} ) {
					next ARTICLE;
				}
			}
			
			my $ArticleCreateTime = $TimeObject->TimeStamp2SystemTime( 
				String => $ArticleMetaData->{CreateTime} 
			);
			
			my $SystemTimeNewer = $TimeObject->TimeStamp2SystemTime(
				String => $Param{ArticleCreateTimeNewerDate},
			);
			
			my $SystemTimeOlder = $TimeObject->TimeStamp2SystemTime(
				String => $Param{ArticleCreateTimeOlderDate},
			);
			
			if (
				( $ArticleCreateTime >= $SystemTimeNewer ) 
				&& ( $ArticleCreateTime <= $SystemTimeOlder ) 
			) 
			{
				$TicketData{AccountedTime} += $ArticleObject->ArticleAccountedTimeGet( ArticleID => $ArticleMetaData->{ArticleID});
			}
		}
		
		if( $TicketData{AccountedTime} > 0 ){
		
			my $AccountedTimeFormat = $ConfigObject->Get('AccountedTimeFormat') || 'Hours';
			if( $AccountedTimeFormat eq 'Hours' ){
				$TicketData{AccountedTime} = sprintf("%.2f", ( $TicketData{AccountedTime}/60 ));
			}
		
			my %Ticket = $TicketObject->TicketGet(
				TicketID => $TicketID,
				UserID   => $Self->{UserID},
			);
			
			# get default columns
			my $Columns = $ConfigObject->Get('AccountedTimeStats::TicketsView::DefaultOverviewColumns') || {};
			my @DefaultColumns;
			for my $Column ( keys %{$Columns} ) {
				if ( $Columns->{$Column} ) {
					push @DefaultColumns, $Column;
				}
			}
			
			# add columns data
			for my $TicketItem (@DefaultColumns){
				$TicketData{$TicketItem} = $Ticket{$TicketItem};
			}
			
			push @Data, \%TicketData;			
		}
	}
	
	return \@Data;
}

sub _Overview {
    my ( $Self, %Param ) = @_;
	
	my %Data = ();

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
	my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
	
	# get list type
    my $TreeView = 0;
    if ( $ConfigObject->Get('Ticket::Frontend::ListType') eq 'tree' ) {
        $TreeView = 1;
    }
	
    $Data{QueuesStrg} = $LayoutObject->AgentQueueListOption(
        Data               => { $QueueObject->GetAllQueues(), },
        Size               => 5,
        Multiple           => 1,
        Name               => 'QueueIDs',
        TreeView           => $TreeView,
        OnChangeSubmit     => 0,
        Class              => 'Modernize',
    );
	
	my %Users = $Kernel::OM->Get('Kernel::System::User')->UserList(
        Type  => 'Long',
        Valid => 1,
    );
	
	$Data{OwnerStrg} = $LayoutObject->BuildSelection(
        Data        => \%Users,
        Name        => 'OwnerIDs',
        Multiple    => 1,
        Size        => 5,
        Translation => 0,
        Class       => 'Modernize',
    );
	
	my %OutputFormats = (
        CSV		=> 'CSV',
        Excel	=> 'Excel',
		Print	=> 'Print',
		Screen	=> 'Screen'
    );
	
	$Data{OutputFormatStrg} = $LayoutObject->BuildSelection(
        Data        => \%OutputFormats,
        Name        => 'OutputFormat',
        Size        => 5,
        Translation => 1,
		SelectedID  => 'Screen',
        Class       => 'Modernize Validate_Required',
    );
	
	my %Counter;
    for my $Number ( 1 .. 60 ) {
        $Counter{$Number} = sprintf( "%02d", $Number );
    }

    # time
    $Data{'AccountedTimePoint'} = $LayoutObject->BuildSelection(
        Data        => \%Counter,
        Name        => 'TimePoint',
        Translation => 0,
    );
    $Data{'AccountedTimePointStart'} = $LayoutObject->BuildSelection(
        Data => {
            Last   => Translatable('within the last ...'),
            Next   => Translatable('within the next ...'),
            Before => Translatable('more than ... ago'),
        },
        Name       => 'TimePointStart',
    );
    $Data{'AccountedTimePointFormat'} = $LayoutObject->BuildSelection(
        Data => {
            minute => Translatable('minute(s)'),
            hour   => Translatable('hour(s)'),
            day    => Translatable('day(s)'),
            week   => Translatable('week(s)'),
            month  => Translatable('month(s)'),
            year   => Translatable('year(s)'),
        },
        Name       => 'TimePointFormat',
    );
    $Data{'AccountedTimeStart'} = $LayoutObject->BuildDateSelection(
        %Data,
        Prefix   => 'TimeStart',
        Format   => 'DateInputFormat',
        DiffTime => -( 60 * 60 * 24 ) * 30,
        Validate => 1,
		ValidateDateNotInFuture => 1,
    );
    $Data{'AccountedTimeStop'} = $LayoutObject->BuildDateSelection(
        %Data,
        Prefix   => 'TimeStop',
        Format   => 'DateInputFormat',
        Validate => 1,
		ValidateDateNotInFuture => 1,
    );
	
	# header
    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();
	# generate output
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentAccountedTimeStats',
        Data         => \%Data
    );

    $Output .= $LayoutObject->Footer();

    return $Output;
}

sub _GeneratePDF {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Title HeadArrayRef DataArray)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => "error",
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $Title        = $Param{Title};
    my @HeadArrayRef = @{ $Param{HeadArrayRef} // [] };
    my @DataArray    = @{ $Param{DataArray} // [] };

    my $PDFObject    = $Kernel::OM->Get('Kernel::System::PDF');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $Page = $LayoutObject->{LanguageObject}->Translate('Page');
    my $Time = $LayoutObject->{Time};

    # get maximum number of pages
    my $MaxPages = $ConfigObject->Get('PDF::MaxPages');
    if ( !$MaxPages || $MaxPages < 1 || $MaxPages > 1000 ) {
        $MaxPages = 100;
    }

    # create the header
    my $CellData;
    my $CounterRow  = 0;
    my $CounterHead = 0;
    for my $Content ( @HeadArrayRef ) {
        $CellData->[$CounterRow]->[$CounterHead]->{Content} = $Content;
        $CellData->[$CounterRow]->[$CounterHead]->{Font}    = 'ProportionalBold';
        $CounterHead++;
    }
    if ( $CounterHead > 0 ) {
        $CounterRow++;
    }

    # create the content array
    for my $Row (@DataArray) {
        my $CounterColumn = 0;
        for my $Content ( @{$Row} ) {
            $CellData->[$CounterRow]->[$CounterColumn]->{Content} = $Content;
            $CounterColumn++;
        }
        $CounterRow++;
    }

    # output 'No matches found', if no content was given
    if ( !$CellData->[0]->[0] ) {
        $CellData->[0]->[0]->{Content} = $LayoutObject->{LanguageObject}->Translate('No matches found.');
    }

    my $TranslateTimeZone = $LayoutObject->{LanguageObject}->Translate('Time Zone');

    # if a time zone was selected
    if ( $Param{TimeZone} ) {
        $Title .= " ($TranslateTimeZone $Param{TimeZone})";
    }

    # page params
    my %PageParam;
    $PageParam{PageOrientation} = 'landscape';
    $PageParam{MarginTop}       = 30;
    $PageParam{MarginRight}     = 40;
    $PageParam{MarginBottom}    = 40;
    $PageParam{MarginLeft}      = 40;

    $PageParam{HeadlineLeft} = $Title;

    # table params
    my %TableParam;
    $TableParam{CellData}            = $CellData;
    $TableParam{Type}                = 'Cut';
    $TableParam{FontSize}            = 6;
    $TableParam{Border}              = 0;
    $TableParam{BackgroundColorEven} = '#DDDDDD';
    $TableParam{Padding}             = 4;

    # create new pdf document
    $PDFObject->DocumentNew(
        Title  => $ConfigObject->Get('Product') . ': ' . $Title,
        Encode => $LayoutObject->{UserCharset},
    );

    # start table output
    $PDFObject->PageNew(
        %PageParam,
		LogoFile    => '',
        FooterRight => $Page . ' 1',
    );

    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => -6,
    );

    # output title
    $PDFObject->Text(
        Text     => $Title,
        FontSize => 13,
    );

    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => -6,
    );

    # output "printed by"
    $PDFObject->Text(
        Text     => $Time,
        FontSize => 9,
    );

    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => -14,
    );

    COUNT:
    for ( 2 .. $MaxPages ) {

        # output table (or a fragment of it)
        %TableParam = $PDFObject->Table( %TableParam, );

        # stop output or output next page
        last COUNT if $TableParam{State};

        $PDFObject->PageNew(
            %PageParam,
            FooterRight => $Page . ' ' . $_,
        );
    }

    return $PDFObject->DocumentOutput();
}

1;